class Actor < ApplicationRecord
  has_secure_password

  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :balance_cents, numericality: { greater_than_or_equal_to: 0 }

  before_save { self.email = email.downcase }

  def balance_dollars
    balance_cents / 100.0
  end

  def sufficient_balance?(amount_cents)
    balance_cents >= amount_cents
  end

  # Atomically deducts balance. Raises InsufficientBalanceError if balance is too low.
  def deduct!(amount_cents)
    with_lock do
      raise InsufficientBalanceError, "Insufficient balance" unless sufficient_balance?(amount_cents)
      decrement!(:balance_cents, amount_cents)
    end
  end

  def credit!(amount_cents)
    increment!(:balance_cents, amount_cents)
  end

  def generate_password_reset_token!
    update!(
      password_reset_token:    SecureRandom.urlsafe_base64(32),
      password_reset_sent_at:  Time.current
    )
    password_reset_token
  end

  def password_reset_expired?
    password_reset_sent_at.nil? || password_reset_sent_at < 2.hours.ago
  end

  def clear_password_reset!
    update!(password_reset_token: nil, password_reset_sent_at: nil)
  end

  def stripe_customer?
    payment_provider == "stripe" && payment_customer_id.present?
  end

  def attach_stripe_customer!(customer_id)
    update!(payment_customer_id: customer_id, payment_provider: "stripe")
  end

  class InsufficientBalanceError < StandardError; end
end
