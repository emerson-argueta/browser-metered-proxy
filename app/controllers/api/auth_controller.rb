module Api
  class AuthController < ApplicationController
    skip_before_action :authenticate_actor!, only: %i[register login refresh forgot_password reset_password]

    # POST /api/auth/register
    def register
      actor = Actor.new(
        email: params.require(:email),
        password: params.require(:password),
        password_confirmation: params.require(:password_confirmation)
      )

      if actor.save
        render json: issue_tokens(actor), status: :created
      else
        render json: { errors: actor.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # POST /api/auth/login
    def login
      actor = Actor.find_by(email: params.require(:email)&.downcase)

      if actor&.authenticate(params.require(:password))
        render json: issue_tokens(actor)
      else
        render json: { error: "Invalid email or password" }, status: :unauthorized
      end
    end

    # POST /api/auth/refresh
    def refresh
      digest = Digest::SHA256.hexdigest(params.require(:refresh_token))
      refresh_token = RefreshToken.find_by(token_digest: digest)

      if refresh_token.nil? || refresh_token.revoked? || refresh_token.expired?
        return render json: { error: "Invalid or expired refresh token" }, status: :unauthorized
      end

      refresh_token.update!(revoked_at: Time.current)
      render json: issue_tokens(refresh_token.actor)
    end

    # POST /api/auth/logout
    def logout
      digest = Digest::SHA256.hexdigest(params.require(:refresh_token))
      RefreshToken.find_by(token_digest: digest, actor_id: @current_actor_id)&.update!(revoked_at: Time.current)

      # Always respond the same way to avoid leaking whether the token was valid
      render json: { message: "Logged out" }
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
        render json: issue_tokens(actor)
      else
        render json: { errors: actor.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    # Builds the { token:, refresh_token: } payload shared by register/login/refresh/reset_password.
    def issue_tokens(actor)
      { token: issue_token(actor), refresh_token: issue_refresh_token(actor) }
    end

    def issue_token(actor)
      payload = {
        actor_id: actor.id.to_s,
        exp: ENV.fetch("JWT_EXPIRY_HOURS", "720").to_i.hours.from_now.to_i
      }
      JWT.encode(payload, jwt_secret, "HS256")
    end

    def issue_refresh_token(actor)
      raw = SecureRandom.hex(32)
      RefreshToken.create!(
        actor: actor,
        token_digest: Digest::SHA256.hexdigest(raw),
        expires_at: ENV.fetch("REFRESH_TOKEN_EXPIRY_DAYS", "365").to_i.days.from_now
      )
      raw
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
