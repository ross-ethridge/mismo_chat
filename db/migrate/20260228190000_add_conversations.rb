class AddConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :conversations do |t|
      t.string :title
      t.timestamps
    end

    add_column :messages, :conversation_id, :integer
    add_index :messages, :conversation_id
    add_foreign_key :messages, :conversations
  end
end
