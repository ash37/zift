class CreateTimesheetExportLines < ActiveRecord::Migration[8.0]
  def change
    create_table :timesheet_export_lines do |t|
      t.references :timesheet_export, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :earnings_rate_id, null: false
      t.json :daily_units, null: false
      t.string :xero_timesheet_id

      t.timestamps
    end
  end
end
