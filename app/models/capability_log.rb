class CapabilityLog < ApplicationRecord
  STATUSES = %w[success failed].freeze

  validates :actor_id, presence: true
  validates :capability, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :this_month, -> { where(invoked_at: Time.current.beginning_of_month..) }
  scope :for_actor, ->(id) { where(actor_id: id) }
  scope :for_provider, ->(p) { where(provider: p) }
  scope :for_capability, ->(c) { where(capability: c) }
end
