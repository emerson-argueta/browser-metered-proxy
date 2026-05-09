class AddPasswordResetToActors < ActiveRecord::Migration[8.1]
  def change
    add_column :actors, :password_reset_token, :string
    add_column :actors, :password_reset_sent_at, :datetime
  end
end
