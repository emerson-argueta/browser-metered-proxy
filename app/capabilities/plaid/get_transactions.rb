module Plaid
  class GetTransactions < BaseCapability
    include PlaidClient

    DEFINITION = {
      capability: "get_transactions",
      version: "1.0",
      provider: "plaid",
      cost: { type: "passthrough" }
    }.freeze

    COUNT = 500

    def call
      item       = external_item_for(payload.fetch(:external_id))
      start_date = Date.parse(payload.fetch(:start_date))
      end_date   = Date.parse(payload.fetch(:end_date, Date.today.to_s))
      offset     = payload.fetch(:offset, 0).to_i

      request = ::Plaid::TransactionsGetRequest.new(
        access_token: item.access_token,
        start_date:   start_date,
        end_date:     end_date,
        options: ::Plaid::TransactionsGetRequestOptions.new(
          count:  COUNT,
          offset: offset
        )
      )
      response = plaid_client.transactions_get(request)

      {
        transactions:       response.transactions.map { |t| serialize(t) },
        total_transactions: response.total_transactions,
        has_more:           offset + response.transactions.length < response.total_transactions,
        next_offset:        offset + response.transactions.length,
        provider_request_id: response.request_id
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
