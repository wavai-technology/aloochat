class Installation::OnboardingController < ApplicationController
  before_action :ensure_installation_onboarding

  def index; end

  def create
    begin
      @user, @account = AccountBuilder.new(
        account_name: onboarding_params.dig(:user, :company),
        user_full_name: onboarding_params.dig(:user, :name),
        email: onboarding_params.dig(:user, :email),
        user_password: params.dig(:user, :password),
        super_admin: true,
        confirmed: true
      ).perform

      if @user
        # Prepare data for ALOOSTUDIO webhook
        first_name, last_name = (onboarding_params.dig(:user, :name) || '').split(' ', 2)
        payload = {
          firstName: first_name,
          lastName: last_name,
          email: onboarding_params.dig(:user, :email),
          password: params.dig(:user, :password),
          companyName: onboarding_params.dig(:user, :company)
        }
        webhook_url = ENV.fetch('ALOOSTUDIO_WEBHOOK_URL', nil)
        api_token = ENV.fetch('ALOOSTUDIO_API_TOKEN', nil)
        # webhook_response = nil
        begin
          conn = Faraday.new do |f|
            f.options.timeout = 60
            f.options.open_timeout = 60
            f.request :json
            f.response :json
            f.adapter Faraday.default_adapter
          end
          response = conn.post(webhook_url, payload) do |req|
            req.headers['x-api-token'] = api_token
            req.headers['Content-Type'] = 'application/json'
          end
          webhook_response = response.body
          Rails.logger.info("ALOOSTUDIO webhook response: #{webhook_response}")
          @user.update(clerk_user_id: webhook_response.dig('clerkId')) if webhook_response['success'] && webhook_response.dig('clerkId')
        rescue StandardError => e
          Rails.logger.error("ALOOSTUDIO webhook call failed: #{e.message}")
        end
      else
        render_error_response(CustomExceptions::Account::SignupFailed.new({}))
      end
    rescue StandardError => e
      redirect_to '/', flash: { error: e.message } and return
    end
    finish_onboarding
    redirect_to '/'
  end

  private

  def onboarding_params
    params.permit(:subscribe_to_updates, user: [:name, :company, :email])
  end

  def finish_onboarding
    ::Redis::Alfred.delete(::Redis::Alfred::CHATWOOT_INSTALLATION_ONBOARDING)
    return if onboarding_params[:subscribe_to_updates].blank?

    ChatwootHub.register_instance(
      onboarding_params.dig(:user, :company),
      onboarding_params.dig(:user, :name),
      onboarding_params.dig(:user, :email)
    )
  end

  def ensure_installation_onboarding
    redirect_to '/' unless ::Redis::Alfred.get(::Redis::Alfred::CHATWOOT_INSTALLATION_ONBOARDING)
  end
end
