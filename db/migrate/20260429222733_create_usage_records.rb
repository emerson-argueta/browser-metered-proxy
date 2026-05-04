class CreateUsageRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :usage_records do |t|
      t.string :user_id, null: false
      t.string :call_type
      t.string :plaid_request_id
      t.integer :raw_cost_cents
      t.integer :markup_cents
      t.integer :total_charged_cents
      t.string :charged_to
      t.string :status
      t.datetime :called_at
      t.text :metadata_json
      t.text :notes

      t.timestamps
    end

    add_index :usage_records, :user_id
    add_index :usage_records, :called_at
  end
end
