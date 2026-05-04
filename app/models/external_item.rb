class ExternalItem < ApplicationRecord
  ITEM_TYPES = %w[owner applicant].freeze

  attr_encrypted :access_token,
    key: -> { ENV.fetch("ENCRYPTION_KEY")[0, 32] },
    attribute: "access_token_encrypted"

  validates :user_id, presence: true
  validates :item_id, presence: true, uniqueness: true
  validates :item_type, inclusion: { in: ITEM_TYPES }

  scope :for_user, ->(id) { where(user_id: id) }
  scope :owner_item, -> { where(item_type: "owner") }
  scope :applicant_item, -> { where(item_type: "applicant") }
end
