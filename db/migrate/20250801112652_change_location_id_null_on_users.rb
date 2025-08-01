class ChangeLocationIdNullOnUsers < ActiveRecord::Migration[8.0]
  def change
    change_column_null :users, :location_id, true
  end
end
