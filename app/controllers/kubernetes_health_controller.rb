class KubernetesHealthController < ActionController::Metal
  # This controller inherits from ActionController::Metal which is the most minimal controller
  # It doesn't include any modules or middleware from ApplicationController
  
  def health
    self.response_body = "OK"
    self.status = 200
    self.content_type = "text/plain"
  end
end
