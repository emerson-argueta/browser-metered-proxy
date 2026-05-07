namespace :credits do
  desc "Seed dev credits for an actor. EMAIL=... AMOUNT_CENTS=100000000 (default $1,000,000)"
  task seed: :environment do
    email        = ENV.fetch("EMAIL") { abort "Usage: rails credits:seed EMAIL=you@example.com" }
    amount_cents = ENV.fetch("AMOUNT_CENTS", "100_000_000").delete("_").to_i

    actor = Actor.find_by!(email: email.downcase)
    actor.update!(balance_cents: amount_cents)

    puts "✓ #{email} balance set to #{amount_cents}¢ ($#{"%.2f" % (amount_cents / 100.0)})"
  end

  desc "Show current balance for an actor. EMAIL=..."
  task balance: :environment do
    email = ENV.fetch("EMAIL") { abort "Usage: rails credits:balance EMAIL=you@example.com" }
    actor = Actor.find_by!(email: email.downcase)
    puts "#{email}: #{actor.balance_cents}¢ ($#{"%.2f" % actor.balance_dollars})"
  end
end
