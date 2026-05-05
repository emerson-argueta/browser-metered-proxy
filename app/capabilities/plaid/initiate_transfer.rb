module Plaid
  class InitiateTransfer < BaseCapability
    DEFINITION = {
      capability: "initiate_transfer",
      version: "1.0",
      provider: "plaid",
      cost: { type: "passthrough" }
    }.freeze

    def call
      item = ExternalItem.find_by!(actor_id: actor_id, provider: "plaid", item_type: "bank_account")
      meta = item.metadata_json ? JSON.parse(item.metadata_json) : {}

      request_obj = ::Plaid::TransferCreateRequest.new(
        access_token: item.access_token_encrypted,
        account_id: meta["account_id"],
        type: "credit",
        network: "ach",
        amount: payload.fetch(:amount).to_s,
        ach_class: "ppd",
        user: {
          legal_name: payload.fetch(:legal_name),
          email_address: payload.fetch(:email_address)
        },
        description: payload[:description] || "Payment"
      )
      response = plaid_client.transfer_create(request_obj)

      {
        transfer_id: response.transfer.id,
        status: response.transfer.status,
        amount: response.transfer.amount,
        provider_request_id: response.request_id
      }
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
