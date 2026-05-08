module StripeCapability
  class CreatePaymentIntentSaved < BaseCapability
    include StripeClient

    DEFINITION = {
      capability: "create_payment_intent_saved",
      version:    "1.0",
      provider:   "stripe",
      cost:       { type: "free" }
    }.freeze

    def call
      amount_cents = Integer(payload.fetch(:amount_cents))
      raise ArgumentError, "amount_cents must be positive" unless amount_cents > 0

      actor = Actor.find(actor_id)
      raise ArgumentError, "No saved payment method" unless actor.stripe_customer?

      # Retrieve default payment method for the customer
      customer = Stripe::Customer.retrieve({
        id:     actor.payment_customer_id,
        expand: [ "default_source", "invoice_settings.default_payment_method" ]
      })
      default_pm = customer.invoice_settings&.default_payment_method
      pm_id = (default_pm.respond_to?(:id) ? default_pm.id : default_pm) ||
              customer.default_source ||
              first_payment_method(actor.payment_customer_id)

      raise ArgumentError, "No payment method on file" unless pm_id

      pi = Stripe::PaymentIntent.create(
        amount:               amount_cents,
        currency:             "usd",
        customer:             actor.payment_customer_id,
        payment_method:       pm_id,
        confirm:              true,
        off_session:          true,
        metadata:             { actor_id: actor_id, capability: "add_credits" }
      )

      raise ArgumentError, "Payment failed (status: #{pi.status})" unless pi.status == "succeeded"

      # Credit balance immediately — payment is already confirmed
      raise ArgumentError, "Already credited" if already_credited?(pi.id)
      actor.credit!(amount_cents)

      {
        credited_cents:      amount_cents,
        balance_cents:       actor.reload.balance_cents,
        balance_dollars:     actor.balance_dollars,
        provider_request_id: pi.id
      }
    end
  end
end
