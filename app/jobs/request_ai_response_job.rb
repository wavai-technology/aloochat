require 'base64'
require 'tempfile'

class RequestAiResponseJob < ApplicationJob
  queue_as :default

  def perform(message)
    Rails.logger.info "[AI_JOB] 🚀 RequestAiResponseJob started for message #{message.id} (source_id: #{message.source_id}, content: '#{message.content&.truncate(50)}', sender: #{message.sender_type})"

    # Additional job-level deduplication check using same key strategy as trigger service
    dedup_key = (message.source_id.presence || "msg_#{message.id}")
    job_redis_key = "ai_job_running:#{dedup_key}"
    job_lock_acquired = Redis::Alfred.set(job_redis_key, Time.current.iso8601, nx: true, ex: 300) # 5 min expiry

    unless job_lock_acquired
      Rails.logger.info "[AI_JOB] ❌ RequestAiResponseJob already running for source_id #{message.source_id} (message #{message.id}), skipping"
      return
    end

    Rails.logger.info "[AI_JOB] ✅ Acquired job lock for source_id #{message.source_id} (message #{message.id})"
    conversation = message.conversation
    ai_agent = conversation.assignee
    human_agent = ai_agent.human_agent
    clerk_id = human_agent&.clerk_user_id

    Rails.logger.info "Conversation: #{conversation.id}, Human Agent: #{human_agent&.id}, Clerk ID: #{clerk_id || 'NOT_FOUND'}"

    unless ai_agent&.is_ai?
      Rails.logger.info "Conversation #{conversation.id} is not assigned to an AI agent. Skipping."
      return
    end

    deployment_url = "#{ENV.fetch('ALOOSTUDIO_BACKEND_URL', 'URL_NOT_SET')}/chat/agent/chat"
    api_token = ENV.fetch('ALOOSTUDIO_API_TOKEN', 'TOKEN_NOT_SET')
    human_agent = ai_agent.human_agent
    clerk_id = human_agent&.clerk_user_id

    Rails.logger.info "AI Agent: #{ai_agent.id}, Human Agent: #{human_agent&.id}, Clerk ID: #{clerk_id || 'NOT_FOUND'}, Agent Key: #{ai_agent.agent_key}"
    Rails.logger.info "Deployment URL: #{deployment_url}, API Token Present: #{api_token != 'TOKEN_NOT_SET'}"

    unless deployment_url.present? && api_token.present? && clerk_id.present? && ai_agent.agent_key.present?
      error_message = "AI agent configuration is missing. URL, token, clerk_id, or agent_key not found for AI agent #{ai_agent.id}"
      Rails.logger.error error_message
      return
    end

    if ai_agent.agent_key.blank?
      error_message = "AI agent #{ai_agent.id} is missing agent_key"
      Rails.logger.error error_message
      return
    end

    messages_for_payload = conversation.messages.last(10).filter_map do |msg|
      # Skip messages with nil content
      next if msg.content.blank?

      {
        role: msg.sender.is_a?(User) ? 'assistant' : 'user',
        content: msg.content
        # timestamp: msg.created_at.iso8601
      }
    end

    Rails.logger.info "Agent key: #{ai_agent.agent_key.inspect}, Messages count: #{messages_for_payload.length}"
    Rails.logger.info "Messages payload: #{messages_for_payload.inspect}"

    ai_payload = {
      agent_key: ai_agent.agent_key,
      messages: messages_for_payload,
      query: message.content,
      conversation_id: conversation.id.to_s
    }

    Rails.logger.info "AI payload before form data: #{ai_payload.inspect}"

    # Generate channel-specific conversation ID for AI context
    ai_conversation_id = generate_ai_conversation_id(conversation)
    Rails.logger.info "Generated AI conversation ID: #{ai_conversation_id} for channel: #{conversation.inbox.channel_type}"

    # Convert to form data as per API documentation
    form_data = {
      agent_key: ai_agent.agent_key,
      messages: messages_for_payload.to_json, # JSON string for messages array
      conversation_id: ai_conversation_id
    }

    # Add query only for text messages, not for audio messages
    audio_attachment = message.attachments.find { |att| att.file_type == 'audio' }
    form_data[:query] = message.content if audio_attachment.blank?

    Rails.logger.info "Form data: #{form_data.inspect}"

    # Log the payload before sending
    Rails.logger.info "Form Data Payload: #{form_data.inspect}"
    Rails.logger.info "Agent Key Present: #{ai_agent.agent_key.present?}"
    Rails.logger.info "Messages Count: #{messages_for_payload.length}"
    Rails.logger.info "Messages JSON: #{messages_for_payload.to_json}"

    headers = {
      'x-api-token' => api_token,
      'clerk-id' => clerk_id
      # NOTE: Removed Content-Type header - RestClient will set it automatically for form data
    }

    begin
      Rails.logger.info "Sending AI request for conversation #{conversation.id} to #{deployment_url}"

      # Prepare multipart request if audio file is present
      if audio_attachment.present?
        Rails.logger.info "[AI_JOB] 🎵 Including audio file in AI request: #{audio_attachment.file.filename}"

        temp_file = nil
        begin
          # Download the audio file to send to AI engine
          audio_file_io = audio_attachment.file.download
          temp_file = Tempfile.new(['audio_for_ai', '.ogg'])
          temp_file.binmode
          temp_file.write(audio_file_io)
          temp_file.rewind

          Rails.logger.info "[AI_JOB] 🎵 Created temp file: #{temp_file.path}, size: #{temp_file.size} bytes"

          # Create multipart request with audio file
          multipart_body = {
            agent_key: form_data[:agent_key],
            messages: form_data[:messages],
            conversation_id: form_data[:conversation_id],
            audio_file: File.new(temp_file.path, 'rb')
          }

          Rails.logger.info "[AI_JOB] 🎵 Sending multipart request with fields: #{multipart_body.keys}"
          Rails.logger.info "[AI_JOB] 🎵 Audio file path: #{temp_file.path}"

          response = HTTParty.post(
            deployment_url,
            body: multipart_body,
            headers: headers.except('Content-Type') # Let HTTParty set multipart content type automatically
          )
        rescue StandardError => e
          Rails.logger.error "[AI_JOB] ❌ Error handling audio file: #{e.message}"
          Rails.logger.error "[AI_JOB] ❌ Backtrace: #{e.backtrace.first(5).join('\n')}"
          raise e
        ensure
          # Clean up temp file
          if temp_file
            temp_file.close
            temp_file.unlink
          end
        end
      else
        # Regular form data request for text messages
        Rails.logger.info "[AI_JOB] 📝 Sending regular form data request with fields: #{form_data.keys}"
        response = HTTParty.post(
          deployment_url,
          body: form_data,
          headers: headers
        )
      end

      Rails.logger.info "Response status: #{response.code}"
      Rails.logger.info "Response body: #{response.body}"

      if response.code == 200
        Rails.logger.info "AI response successful for conversation #{conversation.id}"
        ai_response_body = JSON.parse(response.body)

        # Handle both text and audio responses from AI engine
        ai_reply_content = ai_response_body['content'] || ai_response_body['agent_response'] || ai_response_body['agent_response_text']
        audio_response = ai_response_body['audio']
        transcribed_text = ai_response_body['transcribed_text']

        Rails.logger.info "[AI_JOB] 📝 AI Response - Text: #{ai_reply_content.present?}, Audio: #{audio_response.present?}, Transcribed: #{transcribed_text}"

        # Determine if original message was audio
        original_was_audio = message.attachments.any? { |att| att.file_type == 'audio' }

        # Create AI message with appropriate content
        message_content = ai_reply_content || transcribed_text || 'Audio response generated'

        ai_message = ::Messages::MessageBuilder.new(
          ai_agent,
          conversation,
          { content: message_content, message_type: :outgoing }
        ).perform

        # Handle audio response if present
        if audio_response.present? && ai_message.persisted?
          Rails.logger.info '[AI_JOB] 🎵 Processing audio response'
          attach_audio_response_to_message(ai_message, audio_response, transcribed_text)
        end

        # Send the AI response back through the appropriate channel
        if ai_message.persisted?
          Rails.logger.info "[AI_JOB] ✅ AI message #{ai_message.id} created successfully, sending to channel"
          send_ai_response_to_channel(ai_message)
          Rails.logger.info "[AI_JOB] ✅ RequestAiResponseJob completed for message #{message.id}"
        else
          Rails.logger.error "[AI_JOB] ❌ Failed to persist AI message for original message #{message.id}"
        end
      else
        Rails.logger.error "Failed to get response from AI agent for conversation #{conversation.id}: #{response.code} #{response.body}"
      end
    rescue HTTParty::Error => e
      Rails.logger.error "AI agent connection error for conversation #{conversation.id}: #{e.message}"
    rescue StandardError => e
      Rails.logger.error "An unexpected error occurred while requesting AI response for conversation #{conversation.id}: #{e.message}"
    ensure
      # Clean up job lock using same key strategy
      dedup_key = (message.source_id.presence || "msg_#{message.id}")
      job_redis_key = "ai_job_running:#{dedup_key}"
      Redis::Alfred.delete(job_redis_key)
      Rails.logger.info "[AI_JOB] 🧹 Cleaned up job lock for source_id #{message.source_id} (message #{message.id})"
    end
  end

  private

  def generate_ai_conversation_id(conversation)
    inbox = conversation.inbox
    base_id = conversation.id.to_s

    case inbox.channel_type
    when 'Channel::Whatsapp'
      # Get phone number from contact
      phone_number = conversation.contact.phone_number&.gsub(/[^\d]/, '') # Remove non-digits
      phone_number.present? ? "whatsapp_#{phone_number}_#{base_id}" : "whatsapp_unknown_#{base_id}"
    when 'Channel::FacebookPage'
      # Get Facebook ID from contact inbox
      facebook_id = conversation.contact_inbox.source_id
      "facebook_#{facebook_id}_#{base_id}"
    when 'Channel::InstagramDirect'
      # Get Instagram ID from contact inbox
      instagram_id = conversation.contact_inbox.source_id
      "instagram_#{instagram_id}_#{base_id}"
    when 'Channel::TwitterProfile'
      # Get Twitter ID from contact inbox
      twitter_id = conversation.contact_inbox.source_id
      "twitter_#{twitter_id}_#{base_id}"
    when 'Channel::TelegramBot'
      # Get Telegram ID from contact inbox
      telegram_id = conversation.contact_inbox.source_id
      "telegram_#{telegram_id}_#{base_id}"
    when 'Channel::Sms'
      # Get phone number from contact
      phone_number = conversation.contact.phone_number&.gsub(/[^\d]/, '') # Remove non-digits
      phone_number.present? ? "sms_#{phone_number}_#{base_id}" : "sms_unknown_#{base_id}"
    when 'Channel::Line'
      # Get Line ID from contact inbox
      line_id = conversation.contact_inbox.source_id
      "line_#{line_id}_#{base_id}"
    else
      # For API channels or unknown types, just use the conversation ID
      base_id
    end
  end

  def send_ai_response_to_channel(ai_message)
    conversation = ai_message.conversation
    inbox = conversation.inbox

    Rails.logger.info "Sending AI response through #{inbox.channel_type} channel for conversation #{conversation.id}"

    case inbox.channel_type
    when 'Channel::Whatsapp'
      send_whatsapp_response(ai_message)
    when 'Channel::FacebookPage'
      send_facebook_response(ai_message)
    when 'Channel::Instagram'
      send_instagram_response(ai_message)
    when 'Channel::Telegram'
      send_telegram_response(ai_message)
    when 'Channel::Sms', 'Channel::TwilioSms'
      send_sms_response(ai_message)
    when 'Channel::Line'
      send_line_response(ai_message)
    when 'Channel::Api', 'Channel::WebWidget'
      # API channels and web widget don't need to send external responses
      Rails.logger.info "AI response created for #{inbox.channel_type} channel conversation #{conversation.id}"
    else
      Rails.logger.warn "Unsupported channel type for AI response: #{inbox.channel_type}"
    end
  rescue StandardError => e
    Rails.logger.error "Failed to send AI response through channel for conversation #{conversation.id}: #{e.message}"
  end

  def send_whatsapp_response(ai_message)
    Whatsapp::SendOnWhatsappService.new(message: ai_message).perform
  end

  def send_facebook_response(ai_message)
    Facebook::SendOnFacebookService.new(message: ai_message).perform
  end

  def send_instagram_response(ai_message)
    Instagram::SendOnInstagramService.new(message: ai_message).perform
  end

  def send_telegram_response(ai_message)
    ::SendReplyJob.perform_later(ai_message.id)
  end

  def send_sms_response(ai_message)
    ::SendReplyJob.perform_later(ai_message.id)
  end

  def send_line_response(ai_message)
    ::SendReplyJob.perform_later(ai_message.id)
  end

  # Attach audio response from AI engine to the message
  def attach_audio_response_to_message(ai_message, audio_base64, transcribed_text = nil)
    return if audio_base64.blank?

    begin
      # Decode base64 audio data
      audio_data = Base64.decode64(audio_base64)
      Rails.logger.info "[AI_JOB] 🎵 Decoded audio data: #{audio_data.bytesize} bytes"

      # Create a temporary file for the audio
      temp_file = Tempfile.new(['ai_audio_response', '.ogg'])
      temp_file.binmode
      temp_file.write(audio_data)
      temp_file.rewind

      # Create attachment
      ai_message.attachments.create!(
        account_id: ai_message.account_id,
        file_type: :audio,
        file: {
          io: temp_file,
          filename: "ai_audio_response_#{Time.current.to_i}.ogg",
          content_type: 'audio/ogg'
        }
      )

      # Update message content to include transcription if available
      ai_message.update!(content: transcribed_text) if transcribed_text.present? && ai_message.content.blank?

      Rails.logger.info "[AI_JOB] ✅ Audio attachment created for message #{ai_message.id}"
    rescue StandardError => e
      Rails.logger.error "[AI_JOB] ❌ Failed to attach audio response: #{e.message}"
    ensure
      temp_file&.close
      temp_file&.unlink
    end
  end
end
