module Capabilities
  module Sendgrid
    module SendgridCapability
      private

      def sendgrid_client
        @sendgrid_client ||= SendGrid::API.new(api_key: ENV.fetch("SENDGRID_API_KEY"))
      end
    end
  end
end
