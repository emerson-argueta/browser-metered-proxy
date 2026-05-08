module StripeCapability
  class CreatePaymentIntent < BaseCapability
    include StripeClient

    DEFINITION = {
      capability: "create_payment_intent",
      version:    "1.0",
      provider:   "stripe",
      cost:       { type: "free" }
    }.freeze

    def call
      amount_cents = Integer(payload.fetch(:amount_cents))
      raise ArgumentError, "amount_cents must be positive" unless amount_cents > 0

      actor       = Actor.find(actor_id)
      customer_id = find_or_create_stripe_customer(actor)

      pi = Stripe::PaymentIntent.create(
        amount:             amount_cents,
        currency:           "usd",
        customer:           customer_id,
        setup_future_usage: "off_session",
        metadata:           { actor_id: actor_id, capability: "add_credits" }
      )

      {
        client_secret:    pi.client_secret,
        payment_intent_id: pi.id,
        publishable_key:  stripe_publishable_key,
        provider_request_id: pi.id
      }
    end
  end
end
