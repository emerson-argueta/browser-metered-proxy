Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # In production, restrict to your actual frontend domain
    origins ENV.fetch("FRONTEND_ORIGIN", "*")

    resource "/api/*",
      headers: :any,
      methods: %i[get post put patch delete options head],
      expose: [ "Authorization" ]
  end
end
