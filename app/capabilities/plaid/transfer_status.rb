module Plaid
  class TransferStatus < BaseCapability
    DEFINITION = {
      capability: "transfer_status",
      version: "1.0",
      provider: "plaid",
      cost: { type: "free" }
    }.freeze

    def call
      request_obj = ::Plaid::TransferGetRequest.new(
        transfer_id: payload.fetch(:transfer_id)
      )
      response = plaid_client.transfer_get(request_obj)

      {
        transfer_id: payload[:transfer_id],
        status: response.transfer.status,
        amount: response.transfer.amount,
        provider_request_id: nil
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
