class AddClerkUserIdToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :clerk_user_id, :string, null: true
    add_index :users, :clerk_user_id, unique: true, where: 'clerk_user_id IS NOT NULL'
  end
end
