module Plaid
  class LinkSession < BaseCapability
    DEFINITION = {
      capability: "link_session",
      version: "1.0",
      provider: "plaid",
      cost: { type: "passthrough" }
    }.freeze

    def call
      products = (payload[:products] || [ "transactions" ]).map do |p|
        ::Plaid::Products.const_get(p.upcase)
      end

      request_obj = ::Plaid::LinkTokenCreateRequest.new(
        user: { client_user_id: actor_id },
        client_name: ENV.fetch("APP_NAME", "App"),
        products: products,
        country_codes: [ ::Plaid::CountryCode::US ],
        language: "en"
      )

      response = plaid_client.link_token_create(request_obj)
      { link_token: response.link_token, provider_request_id: response.request_id }
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
