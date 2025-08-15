class AddUniqueIndexToXeroItems < ActiveRecord::Migration[7.1]
  def change
    change_column_null :xero_items, :xero_item_id, false
    add_index :xero_items, :xero_item_id, unique: true, if_not_exists: true
  end
end
