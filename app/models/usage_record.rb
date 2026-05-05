class UsageRecord < ApplicationRecord
  validates :user_id, presence: true
  validates :provider, presence: true

  scope :this_month, -> { where(called_at: Time.current.beginning_of_month..) }
  scope :for_user, ->(id) { where(user_id: id) }
  scope :for_provider, ->(p) { where(provider: p) }
end
