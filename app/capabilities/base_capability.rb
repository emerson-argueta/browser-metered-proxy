class BaseCapability
  DEFINITION = {
    capability: nil,
    version: "1.0",
    provider: nil,
    cost: { type: "free" }
  }.freeze

  attr_reader :actor_id, :payload, :envelope

  def initialize(actor_id:, payload:, envelope: {})
    @actor_id = actor_id
    @payload  = payload
    @envelope = envelope
  end

  def self.capability_name = self::DEFINITION[:capability]
  def self.version         = self::DEFINITION[:version] || "1.0"
  def self.provider        = self::DEFINITION[:provider]

  # Subclasses implement this — validate payload, call provider, store result, return data.
  def call
    raise NotImplementedError
  end

  # Entry point — checks balance, runs the capability, deducts cost, writes CapabilityLog.
  def execute
    invoked_at = Time.current
    costs = CostCalculator.calculate(
      provider:   self.class.provider.to_s,
      capability: self.class.capability_name
    )

    # Enforce balance before doing any external work.
    if costs[:total_charged_cents] > 0
      actor = Actor.find(actor_id)
      unless actor.sufficient_balance?(costs[:total_charged_cents])
        raise Actor::InsufficientBalanceError,
          "Insufficient balance. Need #{costs[:total_charged_cents]}¢, have #{actor.balance_cents}¢."
      end
    end

    result = call

    # Deduct atomically after success (with_lock guards against races).
    Actor.find(actor_id).deduct!(costs[:total_charged_cents]) if costs[:total_charged_cents] > 0

    CapabilityLog.create!(
      actor_id:           actor_id,
      capability:         self.class.capability_name,
      version:            self.class.version,
      provider:           self.class.provider,
      provider_request_id: result[:provider_request_id],
      raw_cost_cents:     costs[:raw_cost_cents],
      markup_cents:       costs[:markup_cents],
      total_charged_cents: costs[:total_charged_cents],
      charged_to:         payload[:charged_to] || "actor",
      metadata_json:      payload[:metadata]&.to_json,
      status:             "success",
      invoked_at:         invoked_at,
      completed_at:       Time.current
    )

    result.merge(costs)
  rescue => e
    CapabilityLog.create!(
      actor_id:           actor_id,
      capability:         self.class.capability_name,
      version:            self.class.version,
      provider:           self.class.provider,
      raw_cost_cents:     0,
      markup_cents:       0,
      total_charged_cents: 0,
      charged_to:         payload[:charged_to] || "actor",
      status:             "failed",
      error_code:         e.class.name,
      invoked_at:         invoked_at,
      completed_at:       Time.current
    )
    raise
  end
end
