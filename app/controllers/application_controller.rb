class ApplicationController < ActionController::API
  before_action :authenticate_landlord!

  private

  def authenticate_landlord!
    token = request.headers["Authorization"]&.split(" ")&.last
    return render json: { error: "Unauthorized" }, status: :unauthorized unless token

    begin
      payload = JWT.decode(token, jwt_secret, true, algorithm: "HS256").first
      @landlord_id = payload["landlord_id"]
    rescue JWT::DecodeError
      render json: { error: "Invalid token" }, status: :unauthorized
    end
  end

  def jwt_secret
    ENV.fetch("JWT_SECRET") { raise "JWT_SECRET env var not set" }
  end

  def plaid_client
    @plaid_client ||= begin
      configuration = Plaid::Configuration.new
      configuration.server_index = {
        "sandbox" => Plaid::Configuration::Environment["sandbox"],
        "development" => Plaid::Configuration::Environment["development"],
        "production" => Plaid::Configuration::Environment["production"]
      }.fetch(ENV.fetch("PLAID_ENV", "sandbox"))
      api_client = Plaid::ApiClient.new(configuration)
      api_client.default_headers["PLAID-CLIENT-ID"] = ENV.fetch("PLAID_CLIENT_ID")
      api_client.default_headers["PLAID-SECRET"] = ENV.fetch("PLAID_SECRET")
      Plaid::PlaidApi.new(api_client)
    end
  end

  MARKUP_RATES = {
    "link_session" => 0.02,
    "income_verify" => 0.02,
    "identity_check" => 0.02,
    "ach_transfer" => 0.01,
    "balance_check" => 0.01
  }.freeze

  PLAID_BASE_COSTS = {
    "link_session" => 50,
    "income_verify" => 150,
    "identity_check" => 100,
    "ach_transfer" => 25,
    "balance_check" => 10
  }.freeze

  def log_usage(call_type:, plaid_request_id: nil, status: "success", **context)
    raw = PLAID_BASE_COSTS[call_type] || 0
    markup = (raw * MARKUP_RATES[call_type]).to_i
    UsageRecord.create!(
      landlord_id: @landlord_id,
      call_type: call_type,
      plaid_request_id: plaid_request_id,
      raw_cost_cents: raw,
      markup_cents: markup,
      total_charged_cents: raw + markup,
      charged_to: context[:charged_to] || "landlord",
      status: status,
      called_at: Time.current,
      property_id: context[:property_id],
      unit_id: context[:unit_id],
      tenant_id: context[:tenant_id]
    )
  end
end
