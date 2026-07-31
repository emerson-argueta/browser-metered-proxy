require "test_helper"

class RefreshTokenTest < ActiveSupport::TestCase
  def build_actor
    Actor.create!(email: "refresh#{SecureRandom.hex(4)}@example.com", password: "password", password_confirmation: "password")
  end

  test "valid with actor, token_digest, and expires_at" do
    token = RefreshToken.new(actor: build_actor, token_digest: "abc123", expires_at: 1.day.from_now)
    assert token.valid?
  end

  test "invalid without token_digest" do
    token = RefreshToken.new(actor: build_actor, expires_at: 1.day.from_now)
    assert_not token.valid?
  end

  test "invalid with duplicate token_digest" do
    actor = build_actor
    RefreshToken.create!(actor: actor, token_digest: "dupe", expires_at: 1.day.from_now)
    token = RefreshToken.new(actor: build_actor, token_digest: "dupe", expires_at: 1.day.from_now)
    assert_not token.valid?
  end

  test "revoked? reflects revoked_at presence" do
    token = RefreshToken.create!(actor: build_actor, token_digest: "rev", expires_at: 1.day.from_now)
    assert_not token.revoked?
    token.update!(revoked_at: Time.current)
    assert token.revoked?
  end

  test "expired? reflects expires_at" do
    token = RefreshToken.new(actor: build_actor, token_digest: "exp", expires_at: 1.day.ago)
    assert token.expired?
    token.expires_at = 1.day.from_now
    assert_not token.expired?
  end

  test "active? is true only when not revoked and not expired" do
    token = RefreshToken.create!(actor: build_actor, token_digest: "act", expires_at: 1.day.from_now)
    assert token.active?

    token.update!(revoked_at: Time.current)
    assert_not token.active?
  end
end
