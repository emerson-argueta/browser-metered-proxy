class CreateActors < ActiveRecord::Migration[8.1]
  def change
    create_table :actors do |t|
      t.string :email, null: false
      t.string :password_digest, null: false

      t.timestamps
    end

    add_index :actors, :email, unique: true
  end
end
