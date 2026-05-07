module Billing
  class GetBalance < BaseCapability
    DEFINITION = {
      capability: "get_balance",
      version: "1.0",
      provider: nil,
      cost: { type: "free" }
    }.freeze

    def call
      actor = Actor.find(actor_id)
      {
        balance_cents:   actor.balance_cents,
        balance_dollars: actor.balance_dollars
      }
    end
  end
end
