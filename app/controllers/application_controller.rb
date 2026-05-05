class ApplicationController < ActionController::API
  before_action :authenticate_user!

  private

  def authenticate_user!
    token = request.headers["Authorization"]&.split(" ")&.last
    return render json: { error: "Unauthorized" }, status: :unauthorized unless token

    begin
      payload = JWT.decode(token, jwt_secret, true, algorithm: "HS256").first
      @current_user_id = payload["user_id"]
    rescue JWT::DecodeError
      render json: { error: "Invalid token" }, status: :unauthorized
    end
  end

  def jwt_secret
    ENV.fetch("JWT_SECRET") { raise "JWT_SECRET env var not set" }
  end

  PROVIDERS_CONFIG = YAML.load_file(Rails.root.join("config/providers.yml")).freeze

  def log_usage(call_type:, provider:, external_request_id: nil, status: "success", charged_to: "user", metadata: {})
    cost_config = PROVIDERS_CONFIG.dig(provider, "call_types", call_type) || {}
    raw = cost_config["base_cost_cents"] || 0
    markup_rate = cost_config["markup_rate"] || 0
    markup = (raw * markup_rate).to_i

    UsageRecord.create!(
      user_id: @current_user_id,
      provider: provider,
      call_type: call_type,
      external_request_id: external_request_id,
      raw_cost_cents: raw,
      markup_cents: markup,
      total_charged_cents: raw + markup,
      charged_to: charged_to,
      status: status,
      called_at: Time.current,
      metadata_json: metadata.presence&.to_json
    )
  end
end
