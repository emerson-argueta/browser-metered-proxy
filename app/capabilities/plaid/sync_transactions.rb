module Plaid
  class SyncTransactions < BaseCapability
    include PlaidClient

    DEFINITION = {
      capability: "sync_transactions",
      version: "1.0",
      provider: "plaid",
      cost: { type: "passthrough" }
    }.freeze

    def call
      item = external_item_for(payload.fetch(:external_id))

      cursor   = payload[:cursor]
      added    = []
      modified = []
      removed  = []
      last_request_id = nil

      loop do
        request = ::Plaid::TransactionsSyncRequest.new(
          access_token: item.access_token,
          cursor: cursor
        )
        response = plaid_client.transactions_sync(request)

        added.concat(response.added)
        modified.concat(response.modified)
        removed.concat(response.removed)
        cursor = response.next_cursor
        last_request_id = response.request_id

        break unless response.has_more
      end

      {
        added:       added.map    { |t| serialize(t) },
        modified:    modified.map { |t| serialize(t) },
        removed:     removed.map  { |t| { plaid_transaction_id: t.transaction_id } },
        next_cursor: cursor,
        provider_request_id: last_request_id
      }
    end

    private

    def serialize(t)
      {
        plaid_transaction_id: t.transaction_id,
        plaid_account_id:     t.account_id,
        name:                 t.name,
        merchant_name:        t.merchant_name,
        amount:               t.amount,
        date:                 t.date,
        pending:              t.pending,
        category:             t.personal_finance_category&.primary
      }
    end
  end
end
