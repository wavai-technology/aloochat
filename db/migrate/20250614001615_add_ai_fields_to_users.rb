class AddAiFieldsToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :is_ai, :boolean, default: false, null: false
    add_column :users, :agent_key, :string
    add_reference :users, :human_agent, foreign_key: { to_table: :users }, index: true, null: true
  end
end
