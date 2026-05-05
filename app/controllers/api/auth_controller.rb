module Api
  class AuthController < ApplicationController
    skip_before_action :authenticate_actor!

    # POST /api/auth/register
    def register
      # Placeholder — user storage not yet implemented.
      # Issue a JWT for the provided actor_id for now.
      actor_id = params.require(:actor_id)
      token = JWT.encode({ actor_id: actor_id, exp: expiry }, jwt_secret, "HS256")
      render json: { token: token }, status: :created
    end

    # POST /api/auth/login
    def login
      actor_id = params.require(:actor_id)
      token = JWT.encode({ actor_id: actor_id, exp: expiry }, jwt_secret, "HS256")
      render json: { token: token }
    end

    private

    def expiry
      ENV.fetch("JWT_EXPIRY_HOURS", "720").to_i.hours.from_now.to_i
    end
  end
end
