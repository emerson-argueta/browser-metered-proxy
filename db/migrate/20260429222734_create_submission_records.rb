class CreateSubmissionRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :submission_records do |t|
      t.string :actor_id, null: false
      t.string :capability, null: false
      t.text :payload
      t.string :signature
      t.string :public_key
      t.string :status, null: false, default: "submitted"
      t.string :idempotency_key

      t.timestamps
    end

    add_index :submission_records, :actor_id
    add_index :submission_records, :idempotency_key, unique: true
    add_index :submission_records, :capability
  end
end
