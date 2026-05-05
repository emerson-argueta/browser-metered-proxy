require "test_helper"

class Api::UsageControllerTest < ActionDispatch::IntegrationTest
  test "log returns 401 without auth" do
    get "/api/usage/log"
    assert_response :unauthorized
  end

  test "summary returns 401 without auth" do
    get "/api/usage/summary"
    assert_response :unauthorized
  end

  test "log returns records for authenticated actor" do
    actor = actors(:one)
    CapabilityLog.create!(
      actor_id: actor.id.to_s,
      capability: "link_session",
      status: "success",
      invoked_at: Time.current
    )

    get "/api/usage/log", headers: auth_headers(actor.id)

    assert_response :ok
    body = response.parsed_body
    assert body["records"].is_a?(Array)
    assert body["total"].present?
  end

  test "summary returns cost breakdown for authenticated actor" do
    actor = actors(:one)

    get "/api/usage/summary", headers: auth_headers(actor.id)

    assert_response :ok
    body = response.parsed_body
    assert body.key?("this_month_total_cents")
    assert body.key?("breakdown_by_capability")
    assert body.key?("breakdown_by_provider")
  end

  test "log filters by capability" do
    actor = actors(:one)
    CapabilityLog.create!(actor_id: actor.id.to_s, capability: "link_session", status: "success", invoked_at: Time.current)
    CapabilityLog.create!(actor_id: actor.id.to_s, capability: "verify_income", status: "success", invoked_at: Time.current)

    get "/api/usage/log", params: { capability: "link_session" }, headers: auth_headers(actor.id)

    assert_response :ok
    assert response.parsed_body["records"].all? { |r| r["capability"] == "link_session" }
  end
end
