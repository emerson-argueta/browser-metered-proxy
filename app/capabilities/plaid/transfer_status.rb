module Capabilities
  module Plaid
    class TransferStatus < BaseCapability
      include Capabilities::Plaid::PlaidCapability

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
    end
  end
end
