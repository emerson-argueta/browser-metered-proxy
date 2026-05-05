module Plaid
  class ExchangeToken < BaseCapability
    DEFINITION = {
      capability: "exchange_token",
      version: "1.0",
      provider: "plaid",
      cost: { type: "free" }
    }.freeze

    def call
      request_obj = ::Plaid::ItemPublicTokenExchangeRequest.new(
        public_token: payload.fetch(:public_token)
      )
      response = plaid_client.item_public_token_exchange(request_obj)

      ExternalItem.create!(
        actor_id: actor_id,
        provider: "plaid",
        external_id: response.item_id,
        item_type: payload[:item_type],
        access_token_encrypted: response.access_token,
        metadata_json: {
          institution_name: payload[:institution_name],
          account_id: payload[:account_id],
          account_name: payload[:account_name],
          account_type: payload[:account_type]
        }.compact.to_json
      )

      { external_id: response.item_id, status: "connected", provider_request_id: response.request_id }
    end

    private

    def plaid_client
      @plaid_client ||= build_plaid_client
    end

    def build_plaid_client
      configuration = ::Plaid::Configuration.new
      configuration.server_index = {
        "sandbox"     => ::Plaid::Configuration::Environment["sandbox"],
        "development" => ::Plaid::Configuration::Environment["development"],
        "production"  => ::Plaid::Configuration::Environment["production"]
      }.fetch(ENV.fetch("PLAID_ENV", "sandbox"))
      api_client = ::Plaid::ApiClient.new(configuration)
      api_client.default_headers["PLAID-CLIENT-ID"] = ENV.fetch("PLAID_CLIENT_ID")
      api_client.default_headers["PLAID-SECRET"]    = ENV.fetch("PLAID_SECRET")
      ::Plaid::PlaidApi.new(api_client)
    end
  end
end
