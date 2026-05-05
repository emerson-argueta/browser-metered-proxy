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
end
