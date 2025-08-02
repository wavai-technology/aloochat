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

    messages_for_payload = conversation.messages.last(10).map do |msg|
      {
        role: msg.sender.is_a?(User) ? 'assistant' : 'user',
        content: msg.content
        # timestamp: msg.created_at.iso8601
      }
    end

    ai_payload = {
      agent_key: ai_agent.agent_key,
      messages: messages_for_payload,
      query: message.content
      # conversation_id: conversation.id.to_s
    }.to_json

    headers = {
      'Content-Type' => 'application/json',
      'x-api-token' => api_token,
      'clerk-id' => clerk_id
    }

    begin
      Rails.logger.info "Sending AI request for conversation #{conversation.id} to #{deployment_url}"
      response = RestClient.post(
        deployment_url,
        ai_payload,
        headers
      )

      if response.code == 200
        Rails.logger.info "AI response successful for conversation #{conversation.id}"
        ai_response_body = JSON.parse(response.body)
        ai_reply_content = ai_response_body['content']

        # Create a new message from the AI agent
        ::Messages::MessageBuilder.new(
          ai_agent,
          conversation,
          { content: ai_reply_content, message_type: :outgoing }
        ).perform
      else
        Rails.logger.error "Failed to get response from AI agent for conversation #{conversation.id}: #{response.code} #{response.body}"
      end
    rescue RestClient::ExceptionWithResponse => e
      Rails.logger.error "AI agent connection error for conversation #{conversation.id}: #{e.response}"
    rescue StandardError => e
      Rails.logger.error "An unexpected error occurred while requesting AI response for conversation #{conversation.id}: #{e.message}"
    end
  end
end
