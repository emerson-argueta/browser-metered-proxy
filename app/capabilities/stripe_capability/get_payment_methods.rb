module StripeCapability
  class GetPaymentMethods < BaseCapability
    include StripeClient

    DEFINITION = {
      capability: "get_payment_methods",
      version:    "1.0",
      provider:   "stripe",
      cost:       { type: "free" }
    }.freeze

    def call
      actor = Actor.find(actor_id)
      unless actor.stripe_customer?
        return {
          payment_methods:     [],
          has_saved_method:    false,
          publishable_key:     ENV["STRIPE_PUBLISHABLE_KEY"].presence,
          provider_request_id: nil
        }
      end

      customer = Stripe::Customer.retrieve(
        actor.payment_customer_id,
        expand: [ "invoice_settings.default_payment_method" ]
      )
      default_pm_id = customer.dig("invoice_settings", "default_payment_method", "id") ||
                      customer.dig("invoice_settings", "default_payment_method")

      pms = Stripe::PaymentMethod.list(
        customer: actor.payment_customer_id,
        type:     "card"
      )

      methods = pms.data.map do |pm|
        {
          id:         pm.id,
          brand:      pm.card.brand,
          last4:      pm.card.last4,
          exp_month:  pm.card.exp_month,
          exp_year:   pm.card.exp_year,
          is_default: pm.id == default_pm_id
        }
      end

      {
        payment_methods:     methods,
        has_saved_method:    methods.any?,
        publishable_key:     stripe_publishable_key,
        provider_request_id: nil
      }
    end
  end
end
