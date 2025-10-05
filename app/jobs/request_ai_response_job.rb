class RequestAiResponseJob < ApplicationJob
  queue_as :default

  def perform(message)
    Rails.logger.info "RequestAiResponseJob started for message #{message.id}"
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

    Rails.logger.info "AI Agent: #{ai_agent.id}, Human Agent: #{human_agent&.id}, Clerk ID: #{clerk_id || 'NOT_FOUND'}"
    Rails.logger.info "Deployment URL: #{deployment_url}, API Token Present: #{api_token != 'TOKEN_NOT_SET'}"

    unless deployment_url.present? && api_token.present? && clerk_id.present?
      error_message = "AI agent configuration is missing. URL, token, or clerk_id not found for AI agent #{ai_agent.id}"
      Rails.logger.error error_message
      return
    end

    unless ai_agent.agent_key.present?
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
      query: message.content,
      conversation_id: ai_conversation_id
    }

    Rails.logger.info "Form data: #{form_data.inspect}"

    headers = {
      'x-api-token' => api_token,
      'clerk-id' => clerk_id
    }

    begin
      Rails.logger.info "Sending AI request for conversation #{conversation.id} to #{deployment_url}"

      # Use form data as per API documentation
      response = HTTParty.post(
        deployment_url,
        body: form_data,
        headers: headers
      )

      Rails.logger.info "Response status: #{response.code}"
      Rails.logger.info "Response body: #{response.body}"

      if response.code == 200
        Rails.logger.info "AI response successful for conversation #{conversation.id}"
        ai_response_body = JSON.parse(response.body)
        ai_reply_content = ai_response_body['content']

        # Create a new message from the AI agent
        ai_message = ::Messages::MessageBuilder.new(
          ai_agent,
          conversation,
          { content: ai_reply_content, message_type: :outgoing }
        ).perform

        # Send the AI response back through the appropriate channel
        send_ai_response_to_channel(ai_message) if ai_message.persisted?
      else
        Rails.logger.error "Failed to get response from AI agent for conversation #{conversation.id}: #{response.code} #{response.body}"
      end
    rescue HTTParty::Error => e
      Rails.logger.error "AI agent connection error for conversation #{conversation.id}: #{e.message}"
    rescue StandardError => e
      Rails.logger.error "An unexpected error occurred while requesting AI response for conversation #{conversation.id}: #{e.message}"
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
    when 'Channel::Telegram'
      send_telegram_response(ai_message)
    when 'Channel::Sms'
      send_sms_response(ai_message)
    when 'Channel::Line'
      send_line_response(ai_message)
    when 'Channel::Api'
      # API channels don't need to send external responses
      Rails.logger.info "AI response created for API channel conversation #{conversation.id}"
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

  def send_telegram_response(ai_message)
    ::SendReplyJob.perform_later(ai_message.id)
  end

  def send_sms_response(ai_message)
    ::SendReplyJob.perform_later(ai_message.id)
  end

  def send_line_response(ai_message)
    ::SendReplyJob.perform_later(ai_message.id)
  end
end
