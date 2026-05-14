namespace :credits do
  desc "Grant free credits to an actor. EMAIL=... AMOUNT=10 (dollars, default $10)"
  task grant: :environment do
    email  = ENV.fetch("EMAIL") { abort "Usage: rails credits:grant EMAIL=you@example.com AMOUNT=10" }
    amount = ENV.fetch("AMOUNT", "10").to_f
    cents  = (amount * 100).round

    actor = Actor.find_by(email: email.downcase)
    abort "No actor found with email: #{email}" unless actor

    actor.credit_free!(cents)
    puts "✓ Granted $#{"%.2f" % amount} to #{email}"
    puts "  New balance: $#{"%.2f" % actor.reload.balance_dollars}"
  end

  desc "Set balance directly for an actor. EMAIL=... AMOUNT=10 (dollars)"
  task set: :environment do
    email  = ENV.fetch("EMAIL") { abort "Usage: rails credits:set EMAIL=you@example.com AMOUNT=10" }
    amount = ENV.fetch("AMOUNT") { abort "AMOUNT required" }.to_f
    cents  = (amount * 100).round

    actor = Actor.find_by(email: email.downcase)
    abort "No actor found with email: #{email}" unless actor

    actor.update!(balance_cents: cents)
    puts "✓ #{email} balance set to $#{"%.2f" % amount}"
  end

  desc "Show current balance for an actor. EMAIL=..."
  task balance: :environment do
    email = ENV.fetch("EMAIL") { abort "Usage: rails credits:balance EMAIL=you@example.com" }
    actor = Actor.find_by(email: email.downcase)
    abort "No actor found with email: #{email}" unless actor
    puts "#{email}: $#{"%.2f" % actor.balance_dollars}"
  end

  desc "List all actors and their balances"
  task list: :environment do
    actors = Actor.order(:email)
    if actors.empty?
      puts "No actors registered yet."
    else
      puts "%-40s %12s %10s" % ["Email", "Balance", "Calls"]
      puts "-" * 65
      actors.each do |a|
        calls = CapabilityLog.where(actor_id: a.id).count
        puts "%-40s %12s %10s" % [a.email, "$#{"%.2f" % a.balance_dollars}", calls]
      end
    end
  end
end
