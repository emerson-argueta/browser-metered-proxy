module Plaid
  class ExchangeToken < BaseCapability
    include PlaidClient

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

      # access_token= uses attr_encrypted — stores encrypted in the DB column.
      ExternalItem.create!(
        actor_id:      actor_id,
        provider:      "plaid",
        external_id:   response.item_id,
        item_type:     payload[:item_type],
        access_token:  response.access_token,
        metadata_json: {
          institution_name: payload[:institution_name],
          account_id:       payload[:account_id],
          account_name:     payload[:account_name],
          account_type:     payload[:account_type]
        }.compact.to_json
      )

      { external_id: response.item_id, status: "connected", provider_request_id: response.request_id }
    end
  end
end
