class AddDetailsToTimesheets < ActiveRecord::Migration[8.0]
  def change
    add_column :timesheets, :notes, :text
    add_column :timesheets, :travel, :integer
  end
end
