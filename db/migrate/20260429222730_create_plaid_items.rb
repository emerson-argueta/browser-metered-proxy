class CreatePlaidItems < ActiveRecord::Migration[8.1]
  def change
    create_table :plaid_items do |t|
      t.string :landlord_id
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
  end
end
