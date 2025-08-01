class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :name
      t.string :email
      t.integer :role
      t.references :location, null: false, foreign_key: true

      t.timestamps
    end
  end
end
