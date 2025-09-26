class CreateComments < ActiveRecord::Migration[8.0]
  def change
    create_table :comments do |t|
      t.text :body, null: false
      t.string :commentable_type, null: false
      t.bigint :commentable_id, null: false
      t.bigint :user_id, null: false
      t.timestamps
    end
    add_index :comments, [:commentable_type, :commentable_id]
    add_index :comments, :user_id
  end
end

