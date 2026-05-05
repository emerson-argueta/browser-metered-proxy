class ExternalItem < ApplicationRecord
  attr_encrypted :access_token,
    key: -> { ENV.fetch("ENCRYPTION_KEY")[0, 32] },
    attribute: "access_token_encrypted"

  validates :user_id, presence: true
  validates :provider, presence: true
  validates :external_id, presence: true, uniqueness: true

  scope :for_user, ->(id) { where(user_id: id) }
  scope :for_provider, ->(p) { where(provider: p) }
end
