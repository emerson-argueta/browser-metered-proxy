module Plaid
  class GetAccounts < BaseCapability
    include PlaidClient

    DEFINITION = {
      capability: "get_accounts",
      version: "1.0",
      provider: "plaid",
      cost: { type: "passthrough" }
    }.freeze

    def call
      item = external_item_for(payload.fetch(:external_id))

      response = plaid_client.accounts_get(
        ::Plaid::AccountsGetRequest.new(access_token: item.access_token)
      )

      accounts = response.accounts.map do |acct|
        {
          plaid_account_id:  acct.account_id,
          name:              acct.name,
          official_name:     acct.official_name,
          account_type:      acct.type.to_s,
          subtype:           acct.subtype.to_s,
          current_balance:   acct.balances.current,
          available_balance: acct.balances.available,
          mask:              acct.mask
        }
      end

      { accounts: accounts, provider_request_id: response.request_id }
    end
  end
end
