module Capabilities
  module Plaid
    class VerifyIncome < BaseCapability
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
end
