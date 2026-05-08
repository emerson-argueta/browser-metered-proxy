module Api
  module Webhooks
    class StripeController < ApplicationController
      skip_before_action :authenticate_request

      def receive
        payload = request.body.read
        sig_header = request.env["HTTP_STRIPE_SIGNATURE"]

        event = Stripe::Webhook.construct_event(
          payload, sig_header, ENV.fetch("STRIPE_WEBHOOK_SECRET")
        )

        case event.type
        when "payment_intent.succeeded"
          handle_payment_intent_succeeded(event.data.object)
        end

        head :ok
      rescue Stripe::SignatureVerificationError
        head :bad_request
      rescue JSON::ParserError
        head :bad_request
      end

      private

      def handle_payment_intent_succeeded(payment_intent)
        actor_id = payment_intent.metadata["actor_id"]
        return unless actor_id

        # Idempotency — skip if already credited via the client-side flow
        return if CapabilityLog.exists?(
          capability:          "add_credits",
          status:              "success",
          provider_request_id: payment_intent.id
        )

        actor = Actor.find_by(id: actor_id)
        return unless actor

        actor.credit!(payment_intent.amount)

        CapabilityLog.create!(
          actor_id:            actor_id,
          capability:          "add_credits",
          provider:            "stripe",
          provider_request_id: payment_intent.id,
          raw_cost_cents:      0,
          markup_cents:        0,
          total_charged_cents: 0,
          charged_to:          "actor",
          status:              "success",
          invoked_at:          Time.current,
          completed_at:        Time.current
        )
      end
    end
  end
end
