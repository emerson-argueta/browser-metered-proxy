class ApplicationController < ActionController::API
  before_action :authenticate_actor!

  private

  def authenticate_actor!
    token = request.headers["Authorization"]&.split(" ")&.last
    return render json: { error: "Unauthorized" }, status: :unauthorized unless token

    begin
      payload = JWT.decode(token, jwt_secret, true, algorithm: "HS256").first
      @current_actor_id = payload["actor_id"]
    rescue JWT::DecodeError
      render json: { error: "Invalid token" }, status: :unauthorized
    end
  end

  def jwt_secret
    ENV.fetch("JWT_SECRET") { raise "JWT_SECRET env var not set" }
  end
end
