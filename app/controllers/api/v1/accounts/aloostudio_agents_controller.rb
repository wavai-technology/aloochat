class Api::V1::Accounts::AloostudioAgentsController < Api::V1::Accounts::BaseController
  before_action :authenticate_user!

  def index
    clerk_id = current_user.clerk_user_id
    return render json: { error: 'Missing clerk_user_id for current user' }, status: :unprocessable_entity unless clerk_id.present?

    backend_url = ENV.fetch('ALOOSTUDIO_BACKEND_URL', nil)
    api_token = ENV.fetch('ALOOSTUDIO_API_TOKEN', nil)
    unless backend_url && api_token
      return render json: { error: 'ALOOSTUDIO_BACKEND_URL or ALOOSTUDIO_API_TOKEN not configured' }, status: :internal_server_error
    end

    url = "#{backend_url}/deployments/aloochat?skip=0&limit=100"
    begin
      conn = Faraday.new do |f|
        f.request :json
        f.response :json, content_type: /json/
        f.adapter Faraday.default_adapter
      end
      response = conn.get(url) do |req|
        req.headers['x-api-token'] = api_token
        req.headers['clerk-id'] = clerk_id
        req.headers['Content-Type'] = 'application/json'
      end
      if response.status == 200
        render json: response.body, status: :ok
      else
        Rails.logger.error("ALOOSTUDIO fetch failed: #{response.status} - #{response.body}")
        render json: { error: 'Failed to fetch deployments from ALOOSTUDIO' }, status: :bad_gateway
      end
    rescue StandardError => e
      Rails.logger.error("ALOOSTUDIO fetch error: #{e.message}")
      render json: { error: 'Error fetching deployments from ALOOSTUDIO' }, status: :internal_server_error
    end
  end
end
