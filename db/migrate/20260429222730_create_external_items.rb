class CreateExternalItems < ActiveRecord::Migration[8.1]
  def change
    create_table :external_items do |t|
      t.string :user_id, null: false
      t.string :access_token_encrypted
      t.string :access_token_encrypted_iv
      t.string :item_id
      t.string :institution_name
      t.string :account_id
      t.string :account_name
      t.string :account_type
      t.string :item_type

      t.timestamps
    end

    add_index :external_items, :item_id, unique: true
    add_index :external_items, :user_id
  end
end
