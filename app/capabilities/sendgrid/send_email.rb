module Capabilities
  module Sendgrid
    class SendEmail < BaseCapability
      include Capabilities::Sendgrid::SendgridCapability

      DEFINITION = {
        capability: "send_email",
        version: "1.0",
        provider: "sendgrid",
        cost: { type: "fixed" }
      }.freeze

      def call
        mail = build_mail
        response = sendgrid_client.client.mail._("send").post(request_body: mail.to_json)

        unless response.status_code.to_i == 202
          raise "SendGrid error #{response.status_code}: #{response.body}"
        end

        { status: "sent", to: payload.fetch(:to) }
      end

      private

      def build_mail
        mail = SendGrid::Mail.new
        mail.from = SendGrid::Email.new(
          email: ENV.fetch("SENDGRID_FROM_EMAIL"),
          name: ENV.fetch("SENDGRID_FROM_NAME", ENV.fetch("APP_NAME", "App"))
        )
        mail.subject = payload[:subject]

        personalization = SendGrid::Personalization.new
        personalization.add_to(SendGrid::Email.new(email: payload.fetch(:to)))

        if payload[:template_id]
          mail.template_id = payload[:template_id]
          (payload[:template_data] || {}).each do |key, value|
            personalization.add_dynamic_template_data({ key => value })
          end
        else
          mail.add_content(SendGrid::Content.new(
            type: "text/html",
            value: payload.fetch(:body)
          ))
        end

        mail.add_personalization(personalization)
        mail
      end
    end
  end
end
