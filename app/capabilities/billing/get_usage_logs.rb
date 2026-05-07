module Billing
  class GetUsageLogs < BaseCapability
    DEFINITION = {
      capability: "get_usage_logs",
      version: "1.0",
      provider: nil,
      cost: { type: "free" }
    }.freeze

    def call
      limit  = [[Integer(payload[:limit] || 50), 1].max, 200].min
      offset = [Integer(payload[:offset] || 0), 0].max

      logs = CapabilityLog
        .where(actor_id: actor_id)
        .order(invoked_at: :desc)
        .limit(limit)
        .offset(offset)

      total_charged = CapabilityLog.where(actor_id: actor_id).sum(:total_charged_cents)
      total_calls   = CapabilityLog.where(actor_id: actor_id).count

      {
        logs: logs.map { |l|
          {
            capability:          l.capability,
            provider:            l.provider,
            total_charged_cents: l.total_charged_cents,
            status:              l.status,
            invoked_at:          l.invoked_at&.iso8601
          }
        },
        total_calls:          total_calls,
        total_charged_cents:  total_charged,
        total_charged_dollars: total_charged / 100.0
      }
    end
  end
end
