class BaseCapability
  DEFINITION = {
    capability: nil,
    version: "1.0",
    provider: nil,
    cost: { type: "free" }
  }.freeze

  attr_reader :actor_id, :payload

  def initialize(actor_id:, payload:)
    @actor_id = actor_id
    @payload  = payload
  end

  def self.capability_name
    self::DEFINITION[:capability]
  end

  def self.version
    self::DEFINITION[:version] || "1.0"
  end

  def self.provider
    self::DEFINITION[:provider]
  end

  # Subclasses implement this — validate payload, call provider, store result, return data.
  def call
    raise NotImplementedError
  end

  # Entry point — runs the capability and writes the CapabilityLog.
  def execute
    invoked_at = Time.current
    costs = CostCalculator.calculate(
      provider: self.class.provider.to_s,
      capability: self.class.capability_name
    )

    result = call

    CapabilityLog.create!(
      actor_id: actor_id,
      capability: self.class.capability_name,
      version: self.class.version,
      provider: self.class.provider,
      provider_request_id: result[:provider_request_id],
      raw_cost_cents: costs[:raw_cost_cents],
      markup_cents: costs[:markup_cents],
      total_charged_cents: costs[:total_charged_cents],
      charged_to: payload[:charged_to] || "actor",
      metadata_json: payload[:metadata]&.to_json,
      status: "success",
      invoked_at: invoked_at,
      completed_at: Time.current
    )

    result.merge(costs)
  rescue => e
    CapabilityLog.create!(
      actor_id: actor_id,
      capability: self.class.capability_name,
      version: self.class.version,
      provider: self.class.provider,
      raw_cost_cents: 0,
      markup_cents: 0,
      total_charged_cents: 0,
      charged_to: payload[:charged_to] || "actor",
      status: "failed",
      error_code: e.class.name,
      invoked_at: invoked_at,
      completed_at: Time.current
    )
    raise
  end
end
