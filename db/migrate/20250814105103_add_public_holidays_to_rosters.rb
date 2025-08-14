class AddPublicHolidaysToRosters < ActiveRecord::Migration[8.0]
  def change
    add_column :rosters, :public_holidays, :text
  end
end
