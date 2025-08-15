# db/migrate/20250815000000_create_xero_items.rb
class CreateXeroItems < ActiveRecord::Migration[7.1]
  def change
    create_table :xero_items do |t|
      t.string :code, null: false                 # Xero Item Code (unique)
      t.string :name                              # Human name from Xero
      t.string :xero_item_id                      # Xero’s GUID for the Item (optional but useful)

      t.timestamps
    end

    add_index :xero_items, :code, unique: true
    add_index :xero_items, :xero_item_id
  end
end
