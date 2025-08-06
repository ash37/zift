class AddAutoClockOffToTimesheets < ActiveRecord::Migration[8.0]
  def change
    add_column :timesheets, :auto_clock_off, :boolean, default: false
  end
end
