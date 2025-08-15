class AddTimesheetToInvoiceExportLines < ActiveRecord::Migration[8.0]
  def change
    add_reference :invoice_export_lines, :timesheet, null: false, foreign_key: true
    add_column :invoice_export_lines, :description, :string

    # These columns are now redundant as we can get the data from the associated timesheet
    remove_column :invoice_export_lines, :hours, :decimal, precision: 10, scale: 2
    remove_column :invoice_export_lines, :start_date, :date
    remove_column :invoice_export_lines, :end_date, :date
  end
end
