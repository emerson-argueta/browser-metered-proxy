class CreateCapabilityLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :capability_logs do |t|
      t.string :actor_id, null: false
      t.string :capability, null: false
      t.string :version
      t.string :provider
      t.string :provider_request_id
      t.integer :raw_cost_cents, null: false, default: 0
      t.integer :markup_cents, null: false, default: 0
      t.integer :total_charged_cents, null: false, default: 0
      t.string :charged_to, null: false, default: "actor"
      t.text :metadata_json
      t.string :status, null: false, default: "success"
      t.string :error_code
      t.datetime :invoked_at, null: false
      t.datetime :completed_at

      t.timestamps
    end

    add_index :capability_logs, :actor_id
    add_index :capability_logs, :invoked_at
    add_index :capability_logs, :provider
    add_index :capability_logs, :capability
  end
end
