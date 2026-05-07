module Plaid
  module PlaidClient
    private

    def plaid_client
      @plaid_client ||= begin
        configuration = ::Plaid::Configuration.new
        configuration.server_index = ::Plaid::Configuration::Environment.fetch(
          ENV.fetch("PLAID_ENV", "sandbox")
        )
        configuration.api_key = {
          "PLAID-CLIENT-ID" => ENV.fetch("PLAID_CLIENT_ID"),
          "PLAID-SECRET"    => ENV.fetch("PLAID_SECRET")
        }
        ::Plaid::PlaidApi.new(::Plaid::ApiClient.new(configuration))
      end
    end

    def external_item_for(external_id)
      ExternalItem.find_by!(actor_id: actor_id, external_id: external_id, provider: "plaid")
    end
  end
end
