module StripeCapability
  module StripeClient
    private

    def beta_mode?
      ENV["BETA_MODE"] == "true"
    end

    def raise_if_beta_mode!
      raise BetaModeError, "Payments are not enabled yet. Contact the app owner for beta access." if beta_mode?
    end

    def max_topup_cents
      Integer(ENV.fetch("MAX_TOPUP_CENTS", "5000"))
    end

    def validate_topup_amount!(amount_cents)
      raise ArgumentError, "amount_cents must be positive" unless amount_cents > 0
      raise ArgumentError, "Top-up amount exceeds the maximum of #{max_topup_cents / 100} dollars" if amount_cents > max_topup_cents
    end

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

    def set_default_payment_method(actor, pi)
      return unless actor.stripe_customer?
      pm_id = pi.payment_method
      return unless pm_id
      Stripe::Customer.update(actor.payment_customer_id, {
        invoice_settings: { default_payment_method: pm_id }
      })
    end

    def first_payment_method(customer_id)
      pms = Stripe::PaymentMethod.list(customer: customer_id, type: "card")
      pms.data.first&.id
    end
  end
end
