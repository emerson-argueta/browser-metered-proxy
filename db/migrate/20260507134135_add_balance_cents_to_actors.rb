class AddBalanceCentsToActors < ActiveRecord::Migration[8.1]
  def change
    add_column :actors, :balance_cents, :integer, null: false, default: 0
  end
end
