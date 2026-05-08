module StripeCapability
  module StripeClient
    private

    def stripe_publishable_key
      ENV.fetch("STRIPE_PUBLISHABLE_KEY")
    end

    def find_or_create_stripe_customer(actor)
      return actor.payment_customer_id if actor.stripe_customer?

      customer = Stripe::Customer.create(
        metadata: { actor_id: actor.id, email: actor.email }
      )
      actor.attach_stripe_customer!(customer.id)
      customer.id
    end

    def verify_payment_intent!(payment_intent_id, expected_cents)
      pi = Stripe::PaymentIntent.retrieve(payment_intent_id)
      raise ArgumentError, "PaymentIntent not succeeded (status: #{pi.status})" unless pi.status == "succeeded"
      raise ArgumentError, "Amount mismatch" unless pi.amount == expected_cents
      pi
    end

    def already_credited?(payment_intent_id)
      CapabilityLog.exists?(
        capability: "add_credits",
        status:     "success",
        provider_request_id: payment_intent_id
      )
    end
  end
end
