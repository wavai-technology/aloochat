class HealthController < ApplicationController
  # Skip authentication and other filters if they exist
  skip_before_action :authenticate_user!, raise: false
  skip_before_action :set_current_user, raise: false
  skip_before_action :check_subscription, raise: false
  skip_before_action :check_installation_config, raise: false
  skip_before_action :set_global_config, raise: false
  skip_around_action :handle_with_exception, raise: false
  # Skip CSRF protection
  skip_before_action :verify_authenticity_token, raise: false

  def show
    render plain: 'OK', status: :ok
  end
end
