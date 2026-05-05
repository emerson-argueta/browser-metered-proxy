module Capabilities
  module Plaid
    module PlaidCapability
      private

      def plaid_client
        @plaid_client ||= begin
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
end
