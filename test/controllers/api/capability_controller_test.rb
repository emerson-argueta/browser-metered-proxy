require "test_helper"

class Api::CapabilityControllerTest < ActionDispatch::IntegrationTest
  test "returns 401 without auth token" do
    post "/api/capability", params: { capability: "link_session", payload: {} }, as: :json
    assert_response :unauthorized
  end

  test "returns 401 with invalid token" do
    post "/api/capability",
      params: { capability: "link_session", payload: {} },
      headers: { "Authorization" => "Bearer bad.token.here" },
      as: :json
    assert_response :unauthorized
  end

  test "returns 404 for unknown capability" do
    actor = actors(:one)

    post "/api/capability",
      params: { capability: "nonexistent", payload: {} },
      headers: auth_headers(actor.id),
      as: :json

    assert_response :not_found
  end
end
