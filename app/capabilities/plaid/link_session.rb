module Capabilities
  module Plaid
    class LinkSession < BaseCapability
      include Capabilities::Plaid::PlaidCapability
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
    end
  end
end
