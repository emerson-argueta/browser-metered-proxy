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

  class InsufficientBalanceError < StandardError; end
end
