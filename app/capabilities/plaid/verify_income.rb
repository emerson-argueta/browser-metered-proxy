module Capabilities
  module Plaid
    class VerifyIncome < BaseCapability
      include Capabilities::Plaid::PlaidCapability
      DEFINITION = {
        capability: "verify_income",
        version: "1.0",
        provider: "plaid",
        cost: { type: "passthrough" }
      }.freeze

      def call
        item = ExternalItem.find_by!(
          actor_id: actor_id,
          provider: "plaid",
          external_id: payload.fetch(:external_id)
        )

        request_obj = ::Plaid::CreditPayrollIncomeGetRequest.new(
          user_token: item.access_token_encrypted
        )
        response = plaid_client.credit_payroll_income_get(request_obj)

        { income_data: response.payroll_income, provider_request_id: response.request_id }
      end
    end
  end
end
