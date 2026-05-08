class AddPaymentFieldsToActors < ActiveRecord::Migration[8.1]
  def change
    add_column :actors, :payment_customer_id, :string
    add_column :actors, :payment_provider, :string
  end
end
