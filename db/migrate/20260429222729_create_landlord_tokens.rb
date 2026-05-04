class CreateLandlordTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :landlord_tokens do |t|
      t.string :landlord_id
      t.string :token_digest
      t.datetime :last_used_at
      t.datetime :expires_at

      t.timestamps
    end
  end
end
