class PlaidItem < ApplicationRecord
  ITEM_TYPES = %w[landlord tenant].freeze

  attr_encrypted :access_token,
    key: -> { ENV.fetch("ENCRYPTION_KEY")[0, 32] },
    attribute: "access_token_encrypted"

  validates :landlord_id, presence: true
  validates :item_id, presence: true, uniqueness: true
  validates :item_type, inclusion: { in: ITEM_TYPES }

  scope :for_landlord, ->(id) { where(landlord_id: id) }
  scope :landlord_bank, -> { where(item_type: "landlord") }
  scope :tenant_bank, -> { where(item_type: "tenant") }
end
