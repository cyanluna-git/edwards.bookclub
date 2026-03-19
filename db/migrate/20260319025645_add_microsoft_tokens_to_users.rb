class AddMicrosoftTokensToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :microsoft_access_token, :text
    add_column :users, :microsoft_refresh_token, :text
    add_column :users, :microsoft_token_expires_at, :datetime
  end
end
