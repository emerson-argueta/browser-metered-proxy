module Capabilities
  module Plaid
    class InitiateTransfer < BaseCapability
      include PlaidCapability
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
    end
  end
end
