# db/migrate/20250816_make_xero_item_id_unique_on_xero_items.rb
class MakeXeroItemIdUniqueOnXeroItems < ActiveRecord::Migration[7.1]
  def change
    # Drop the existing non-unique index (safe if it doesn't exist)
    remove_index :xero_items, name: "index_xero_items_on_xero_item_id", if_exists: true

    # Recreate it as unique (keep the same name so the controller's unique_by works)
    add_index :xero_items, :xero_item_id,
              unique: true,
              name: "index_xero_items_on_xero_item_id"
  end
end
