class HealthzController < ActionController::Base
  # This controller inherits directly from ActionController::Base
  # to avoid any filters or middleware from ApplicationController
  
  def show
    render plain: 'OK', status: :ok
  end
end
