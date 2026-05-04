class CreateUserTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :user_tokens do |t|
      t.string :user_id
      t.string :token_digest
      t.datetime :last_used_at
      t.datetime :expires_at

      t.timestamps
    end
  end
end
