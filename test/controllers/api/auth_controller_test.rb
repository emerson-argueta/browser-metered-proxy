require "test_helper"

class Api::AuthControllerTest < ActionDispatch::IntegrationTest
  test "register creates actor and returns token" do
    post "/api/auth/register", params: {
      email: "new@example.com",
      password: "password",
      password_confirmation: "password"
    }, as: :json

    assert_response :created
    assert response.parsed_body["token"].present?
    assert response.parsed_body["refresh_token"].present?
  end

  test "register returns errors for invalid params" do
    post "/api/auth/register", params: {
      email: "bad-email",
      password: "password",
      password_confirmation: "password"
    }, as: :json

    assert_response :unprocessable_entity
    assert response.parsed_body["errors"].present?
  end

  test "register returns error for duplicate email" do
    Actor.create!(email: "taken@example.com", password: "password", password_confirmation: "password")

    post "/api/auth/register", params: {
      email: "taken@example.com",
      password: "password",
      password_confirmation: "password"
    }, as: :json

    assert_response :unprocessable_entity
  end

  test "login returns token with valid credentials" do
    Actor.create!(email: "login@example.com", password: "secret", password_confirmation: "secret")

    post "/api/auth/login", params: {
      email: "login@example.com",
      password: "secret"
    }, as: :json

    assert_response :ok
    assert response.parsed_body["token"].present?
    assert response.parsed_body["refresh_token"].present?
  end

  test "login returns unauthorized with wrong password" do
    Actor.create!(email: "wrong@example.com", password: "correct", password_confirmation: "correct")

    post "/api/auth/login", params: {
      email: "wrong@example.com",
      password: "incorrect"
    }, as: :json

    assert_response :unauthorized
    assert_equal "Invalid email or password", response.parsed_body["error"]
  end

  test "login returns unauthorized for unknown email" do
    post "/api/auth/login", params: {
      email: "ghost@example.com",
      password: "password"
    }, as: :json

    assert_response :unauthorized
  end

  test "refresh rotates the refresh token and returns a new access token" do
    Actor.create!(email: "refresh@example.com", password: "secret", password_confirmation: "secret")
    post "/api/auth/login", params: { email: "refresh@example.com", password: "secret" }, as: :json
    original_refresh_token = response.parsed_body["refresh_token"]

    post "/api/auth/refresh", params: { refresh_token: original_refresh_token }, as: :json

    assert_response :ok
    assert response.parsed_body["token"].present?
    assert response.parsed_body["refresh_token"].present?
    assert_not_equal original_refresh_token, response.parsed_body["refresh_token"]

    old_digest = Digest::SHA256.hexdigest(original_refresh_token)
    assert RefreshToken.find_by(token_digest: old_digest).revoked?
  end

  test "refresh rejects an already-used (rotated) refresh token" do
    Actor.create!(email: "reuse@example.com", password: "secret", password_confirmation: "secret")
    post "/api/auth/login", params: { email: "reuse@example.com", password: "secret" }, as: :json
    original_refresh_token = response.parsed_body["refresh_token"]

    post "/api/auth/refresh", params: { refresh_token: original_refresh_token }, as: :json
    assert_response :ok

    post "/api/auth/refresh", params: { refresh_token: original_refresh_token }, as: :json
    assert_response :unauthorized
    assert_equal "Invalid or expired refresh token", response.parsed_body["error"]
  end

  test "refresh rejects an expired refresh token" do
    actor = Actor.create!(email: "expired@example.com", password: "secret", password_confirmation: "secret")
    raw = SecureRandom.hex(32)
    RefreshToken.create!(actor: actor, token_digest: Digest::SHA256.hexdigest(raw), expires_at: 1.day.ago)

    post "/api/auth/refresh", params: { refresh_token: raw }, as: :json

    assert_response :unauthorized
    assert_equal "Invalid or expired refresh token", response.parsed_body["error"]
  end

  test "refresh rejects an unknown refresh token" do
    post "/api/auth/refresh", params: { refresh_token: "not-a-real-token" }, as: :json

    assert_response :unauthorized
    assert_equal "Invalid or expired refresh token", response.parsed_body["error"]
  end

  test "logout revokes the refresh token when authenticated" do
    Actor.create!(email: "logout@example.com", password: "secret", password_confirmation: "secret")
    post "/api/auth/login", params: { email: "logout@example.com", password: "secret" }, as: :json
    access_token = response.parsed_body["token"]
    refresh_token = response.parsed_body["refresh_token"]

    post "/api/auth/logout",
      params: { refresh_token: refresh_token },
      headers: { "Authorization" => "Bearer #{access_token}" },
      as: :json

    assert_response :ok
    assert_equal "Logged out", response.parsed_body["message"]

    digest = Digest::SHA256.hexdigest(refresh_token)
    assert RefreshToken.find_by(token_digest: digest).revoked?
  end

  test "logout requires a valid access token" do
    post "/api/auth/logout", params: { refresh_token: "whatever" }, as: :json

    assert_response :unauthorized
  end

  test "logout responds the same way even with a bogus refresh token" do
    Actor.create!(email: "logout2@example.com", password: "secret", password_confirmation: "secret")
    post "/api/auth/login", params: { email: "logout2@example.com", password: "secret" }, as: :json
    access_token = response.parsed_body["token"]

    post "/api/auth/logout",
      params: { refresh_token: "bogus-token" },
      headers: { "Authorization" => "Bearer #{access_token}" },
      as: :json

    assert_response :ok
    assert_equal "Logged out", response.parsed_body["message"]
  end
end
