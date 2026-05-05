ENV["RAILS_ENV"] ||= "test"
ENV["JWT_SECRET"] ||= "test_secret_for_tests_only"
ENV["ENCRYPTION_KEY"] ||= "test_encryption_key_32_chars_min"

require_relative "../config/environment"
require "rails/test_help"

BCrypt::Engine.cost = BCrypt::Engine::MIN_COST

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    fixtures :all

    def auth_token(actor_id)
      payload = { actor_id: actor_id.to_s, exp: 24.hours.from_now.to_i }
      JWT.encode(payload, ENV["JWT_SECRET"], "HS256")
    end

    def auth_headers(actor_id)
      { "Authorization" => "Bearer #{auth_token(actor_id)}" }
    end
  end
end
