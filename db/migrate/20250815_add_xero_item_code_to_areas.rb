# db/migrate/20250815_add_xero_item_code_to_areas.rb
class AddXeroItemCodeToAreas < ActiveRecord::Migration[7.1]
  def change
    add_column :areas, :xero_item_code, :string
    add_index  :areas, :xero_item_code
  end
end
