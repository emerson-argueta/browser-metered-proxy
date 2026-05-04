class UsageRecord < ApplicationRecord
  CALL_TYPES = %w[link_session income_verify identity_check ach_transfer balance_check].freeze

  validates :landlord_id, presence: true
  validates :call_type, inclusion: { in: CALL_TYPES }

  scope :this_month, -> { where(called_at: Time.current.beginning_of_month..) }
  scope :for_landlord, ->(id) { where(landlord_id: id) }
end
