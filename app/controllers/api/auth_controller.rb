module Api
  class AuthController < ApplicationController
    skip_before_action :authenticate_actor!

    # POST /api/auth/register
    def register
      actor = Actor.new(
        email: params.require(:email),
        password: params.require(:password),
        password_confirmation: params.require(:password_confirmation)
      )

      if actor.save
        render json: { token: issue_token(actor) }, status: :created
      else
        render json: { errors: actor.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # POST /api/auth/login
    def login
      actor = Actor.find_by(email: params.require(:email)&.downcase)

      if actor&.authenticate(params.require(:password))
        render json: { token: issue_token(actor) }
      else
        render json: { error: "Invalid email or password" }, status: :unauthorized
      end
    end

    private

    def issue_token(actor)
      payload = {
        actor_id: actor.id.to_s,
        exp: ENV.fetch("JWT_EXPIRY_HOURS", "720").to_i.hours.from_now.to_i
      }
      JWT.encode(payload, jwt_secret, "HS256")
    end
  end
end
