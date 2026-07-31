class RefreshToken < ApplicationRecord
  belongs_to :actor

  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true

  def revoked?
    revoked_at.present?
  end

  def expired?
    expires_at < Time.current
  end

  def active?
    !revoked? && !expired?
  end
end
