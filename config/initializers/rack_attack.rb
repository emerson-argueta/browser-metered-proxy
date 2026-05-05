class Rack::Attack
  # Throttle login attempts — 5 per minute per IP
  throttle("auth/login", limit: 5, period: 1.minute) do |req|
    req.ip if req.path == "/api/auth/login" && req.post?
  end

  # Throttle registration attempts — 3 per minute per IP
  throttle("auth/register", limit: 3, period: 1.minute) do |req|
    req.ip if req.path == "/api/auth/register" && req.post?
  end

  # Throttle capability dispatch — 60 per minute per IP
  throttle("capability/dispatch", limit: 60, period: 1.minute) do |req|
    req.ip if req.path == "/api/capability" && req.post?
  end

  self.throttled_responder = lambda do |_req|
    [
      429,
      { "Content-Type" => "application/json" },
      [ { error: "Too many requests. Please try again later." }.to_json ]
    ]
  end
end
