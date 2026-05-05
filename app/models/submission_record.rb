class SubmissionRecord < ApplicationRecord
  STATUSES = %w[submitted reviewed accepted rejected].freeze

  validates :actor_id, presence: true
  validates :capability, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :idempotency_key, uniqueness: true, allow_nil: true

  scope :for_actor, ->(id) { where(actor_id: id) }
end
