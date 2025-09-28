class AddUnscheduledFlagToShifts < ActiveRecord::Migration[8.0]
  def change
    add_column :shifts, :unscheduled, :boolean, null: false, default: false
    add_index  :shifts, :unscheduled
  end
end

