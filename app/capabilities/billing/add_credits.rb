module Billing
  class AddCredits < BaseCapability
    include StripeCapability::StripeClient

    DEFINITION = {
      capability: "add_credits",
      version:    "1.0",
      provider:   nil,
      cost:       { type: "free" }
    }.freeze

    def call
      amount_cents = Integer(payload.fetch(:amount_cents))
      raise ArgumentError, "amount_cents must be positive" unless amount_cents > 0

      actor = Actor.find(actor_id)

      if ENV["REQUIRE_PAYMENT"] == "true"
        payment_intent_id = payload.fetch(:payment_intent_id)
        raise ArgumentError, "Already credited for this payment" if already_credited?(payment_intent_id)
        verify_payment_intent!(payment_intent_id, amount_cents)
      end

      actor.credit!(amount_cents)

      {
        credited_cents:      amount_cents,
        balance_cents:       actor.reload.balance_cents,
        balance_dollars:     actor.balance_dollars,
        provider_request_id: payload[:payment_intent_id]
      }
    end
  end
end
