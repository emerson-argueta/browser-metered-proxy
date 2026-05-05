class CreateExternalItems < ActiveRecord::Migration[8.1]
  def change
    create_table :external_items do |t|
      t.string :user_id, null: false
      t.string :provider, null: false
      t.string :item_type
      t.string :external_id
      t.string :access_token_encrypted
      t.string :access_token_encrypted_iv
      t.text :metadata_json

      t.timestamps
    end

    add_index :external_items, :external_id, unique: true
    add_index :external_items, :user_id
    add_index :external_items, :provider
  end
end
