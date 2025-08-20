class AddTimesheetFlagsToAreas < ActiveRecord::Migration[7.1]
  def change
    add_column :areas, :show_timesheet_notes, :boolean, null: false, default: true
    add_column :areas, :show_timesheet_travel, :boolean, null: false, default: true
  end
end
