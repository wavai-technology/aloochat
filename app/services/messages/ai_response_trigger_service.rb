class Messages::AiResponseTriggerService
  pattr_initialize [:message!]

  def perform
    return unless should_trigger_ai_response?

    Rails.logger.info "Triggering AI response for message #{message.id} in conversation #{message.conversation_id} (source_id: #{message.source_id})"
    RequestAiResponseJob.perform_later(message)
  end

  private

  def should_trigger_ai_response?
    return false unless message.persisted?
    return false unless message.incoming?
    return false unless message.conversation.present?
    return false unless message.conversation.assignee.present?
    return false unless message.conversation.assignee.is_ai?

    # Skip if conversation is resolved or snoozed
    return false if message.conversation.resolved? || message.conversation.snoozed?

    # Check if we've already triggered AI response for this message
    # Use both message ID and source_id for better deduplication
    redis_key = "ai_response_triggered:#{message.id}:#{message.source_id}"
    existing_trigger = Redis::Alfred.get(redis_key)
    if existing_trigger
      Rails.logger.info "AI response already triggered for message #{message.id} (source_id: #{message.source_id}) at #{existing_trigger}, skipping"
      return false
    end

    # Mark this message as having triggered AI response (expires in 1 hour)
    timestamp = Time.current.iso8601
    Redis::Alfred.setex(redis_key, timestamp, 3600)

    Rails.logger.info "AI response conditions met for message #{message.id}: " \
                      "assignee=#{message.conversation.assignee.id}, " \
                      "is_ai=#{message.conversation.assignee.is_ai?}, " \
                      "status=#{message.conversation.status}"

    true
  end
end
