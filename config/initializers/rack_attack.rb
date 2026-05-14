class Rack::Attack
  # ── Auth ─────────────────────────────────────────────────────────────────────

  # Login: 5 attempts per minute per IP
  throttle("auth/login/ip", limit: 5, period: 1.minute) do |req|
    req.ip if req.path == "/api/auth/login" && req.post?
  end

  # Registration: 3 per minute per IP (burst protection)
  throttle("auth/register/ip/minute", limit: 3, period: 1.minute) do |req|
    req.ip if req.path == "/api/auth/register" && req.post?
  end

  # Registration: 10 per hour per IP (bulk account creation protection)
  throttle("auth/register/ip/hour", limit: 10, period: 1.hour) do |req|
    req.ip if req.path == "/api/auth/register" && req.post?
  end

  # ── Capabilities ─────────────────────────────────────────────────────────────

  # Per IP: 60 per minute (existing)
  throttle("capability/dispatch/ip", limit: 60, period: 1.minute) do |req|
    req.ip if req.path == "/api/capability" && req.post?
  end

  # Per actor (JWT): 60 per minute — prevents authenticated abuse from multiple IPs
  throttle("capability/dispatch/actor", limit: 60, period: 1.minute) do |req|
    if req.path == "/api/capability" && req.post?
      auth = req.get_header("HTTP_AUTHORIZATION").to_s
      token = auth.delete_prefix("Bearer ").strip
      token.presence
    end
  end

  # ── Response ─────────────────────────────────────────────────────────────────

  self.throttled_responder = lambda do |_req|
    [
      429,
      { "Content-Type" => "application/json" },
      [ { error: "Too many requests. Please try again later." }.to_json ]
    ]
  end
end
