class CreateUsageRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :usage_records do |t|
      t.string :landlord_id
      t.string :call_type
      t.string :plaid_request_id
      t.string :property_id
      t.string :unit_id
      t.string :tenant_id
      t.integer :raw_cost_cents
      t.integer :markup_cents
      t.integer :total_charged_cents
      t.string :charged_to
      t.string :status
      t.datetime :called_at
      t.text :notes

      t.timestamps
    end
  end
end
