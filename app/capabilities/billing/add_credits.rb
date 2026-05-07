module Billing
  class AddCredits < BaseCapability
    DEFINITION = {
      capability: "add_credits",
      version: "1.0",
      provider: nil,
      cost: { type: "free" }
    }.freeze

    def call
      amount_cents = Integer(payload.fetch(:amount_cents))
      raise ArgumentError, "amount_cents must be positive" unless amount_cents > 0

      # In production: verify payment before crediting.
      #   payment_intent_id = payload.fetch(:stripe_payment_intent_id)
      #   StripeVerifier.verify!(payment_intent_id, amount_cents)
      #
      # In dev: amount_cents is added directly (no payment required).
      # Set REQUIRE_PAYMENT=true in production env to enforce Stripe verification.
      if ENV["REQUIRE_PAYMENT"] == "true"
        raise NotImplementedError, "Stripe payment verification not yet implemented"
      end

      actor = Actor.find(actor_id)
      actor.credit!(amount_cents)

      {
        credited_cents:  amount_cents,
        balance_cents:   actor.reload.balance_cents,
        balance_dollars: actor.balance_dollars
      }
    end
  end
end
