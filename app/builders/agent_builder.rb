# The AgentBuilder class is responsible for creating a new agent.
# It initializes with necessary attributes and provides a perform method
# to create a user and account user in a transaction.
class AgentBuilder
  # Initializes an AgentBuilder with necessary attributes.
  pattr_initialize [
    { email: nil },
    { name: '' },
    :inviter,
    :account,
    { role: :agent },
    { availability: :offline },
    { auto_offline: false },
    { is_ai: false },
    :ai_agent_id,
    :agent_key,
    :human_agent_id
  ]

  # Creates a user and account user in a transaction.
  # @return [User] the created user.
  def perform
    ActiveRecord::Base.transaction do
      @user = is_ai ? create_ai_agent : create_human_agent
      create_account_user
    end
    @user
  end

  private

  # Creates a human agent user.
  # @return [User] the found or created user.
  def create_human_agent
    user = User.from_email(email)
    return user if user

    temp_password = "1!aA#{SecureRandom.alphanumeric(12)}"
    User.create!(email: email, name: name, password: temp_password, password_confirmation: temp_password)
  end

  # Creates an AI agent user.
  # @return [User] the created AI user.
  def create_ai_agent
    # Generate a unique, non-routable email for the AI agent
    domain = account.domain.presence || 'a.bleep.ai'
    ai_email = "ai-agent-#{ai_agent_id}@#{domain}"
    Rails.logger.info "[AgentBuilder#create_ai_agent] Attempting to create AI agent with email: #{ai_email}"

    temp_password = "1!aA#{SecureRandom.alphanumeric(12)}"
    user = User.new(
      email: ai_email,
      name: name,
      password: temp_password,
      password_confirmation: temp_password,
      is_ai: true,
      agent_key: agent_key,
      human_agent_id: human_agent_id
    )
    # AI agents don't need to confirm their email
    user.skip_confirmation!
    user.save!
    user
  end

  # Checks if the user needs confirmation.
  # @return [Boolean] true if the user is persisted and not confirmed, false otherwise.
  def user_needs_confirmation?
    # AI agents are confirmed automatically
    return false if is_ai

    @user.persisted? && !@user.confirmed?
  end

  # Creates an account user linking the user to the current account.
  def create_account_user
    AccountUser.create!({
      account_id: account.id,
      user_id: @user.id,
      inviter_id: inviter&.id
    }.merge({
      role: role,
      availability: availability,
      auto_offline: auto_offline
    }.compact))
  end
end
