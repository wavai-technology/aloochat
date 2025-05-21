class HealthController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :set_current_user
  skip_before_action :check_subscription
  skip_before_action :check_installation_config
  skip_before_action :set_global_config
  skip_around_action :handle_with_exception

  def show
    render plain: 'OK', status: :ok
  end
end
