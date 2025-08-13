class CreateTimesheetExports < ActiveRecord::Migration[8.0]
  def change
    create_table :timesheet_exports do |t|
      t.string :idempotency_key, null: false
      t.date :pay_period_start, null: false
      t.date :pay_period_end, null: false
      t.string :status, null: false, default: 'pending'
      t.integer :exported_count, default: 0
      t.integer :total_count, default: 0
      t.text :error_blob

      t.timestamps
    end

    add_index :timesheet_exports, :idempotency_key, unique: true
  end
end
