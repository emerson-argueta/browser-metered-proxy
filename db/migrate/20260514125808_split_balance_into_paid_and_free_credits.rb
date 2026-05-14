class SplitBalanceIntoPaidAndFreeCredits < ActiveRecord::Migration[8.1]
  def up
    add_column :actors, :paid_balance_cents, :integer, default: 0, null: false
    add_column :actors, :free_balance_cents, :integer, default: 0, null: false

    # Treat all existing balance as paid since we can't know the source
    execute "UPDATE actors SET paid_balance_cents = COALESCE((SELECT balance_cents FROM actors a2 WHERE a2.id = actors.id), 0)"

    remove_column :actors, :balance_cents
  end

  def down
    add_column :actors, :balance_cents, :integer, default: 0, null: false
    execute "UPDATE actors SET balance_cents = paid_balance_cents + free_balance_cents"
    remove_column :actors, :paid_balance_cents
    remove_column :actors, :free_balance_cents
  end
end
