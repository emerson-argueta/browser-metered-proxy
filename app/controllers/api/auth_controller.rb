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

    # POST /api/auth/forgot_password
    def forgot_password
      actor = Actor.find_by(email: params.require(:email).downcase)

      if actor
        token = actor.generate_password_reset_token!
        reset_url = "#{params.require(:reset_base_url)}?token=#{token}"
        send_reset_email(actor, reset_url)
      end

      # Always respond the same way to avoid email enumeration
      render json: { message: "If that email exists you will receive a reset link shortly." }
    end

    # POST /api/auth/reset_password
    def reset_password
      actor = Actor.find_by(password_reset_token: params.require(:token))

      if actor.nil? || actor.password_reset_expired?
        return render json: { error: "Reset link is invalid or has expired." }, status: :unprocessable_entity
      end

      if actor.update(
        password: params.require(:password),
        password_confirmation: params.require(:password_confirmation)
      )
        actor.clear_password_reset!
        render json: { token: issue_token(actor) }
      else
        render json: { errors: actor.errors.full_messages }, status: :unprocessable_entity
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

    def send_reset_email(actor, reset_url)
      return unless ENV["RESEND_API_KEY"].present?

      Resend.api_key = ENV["RESEND_API_KEY"]
      Resend::Emails.send({
        from:    "#{ENV.fetch("APP_NAME", "App")} <#{ENV.fetch("RESEND_FROM_EMAIL")}>",
        to:      actor.email,
        subject: "Reset your #{ENV.fetch("APP_NAME", "App")} password",
        html:    <<~HTML
          <p>Hi,</p>
          <p>Click the link below to reset your password. This link expires in 2 hours.</p>
          <p><a href="#{reset_url}">Reset Password</a></p>
          <p>If you didn't request this, you can ignore this email.</p>
        HTML
      })
    rescue => e
      Rails.logger.error "[auth] password reset email failed: #{e.message}"
    end
  end
end
