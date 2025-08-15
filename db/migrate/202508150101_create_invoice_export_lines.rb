class CreateInvoiceExportLines < ActiveRecord::Migration[8.0]
  def change
    create_table :invoice_export_lines do |t|
      t.references :invoice_export, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
      t.references :area, null: false, foreign_key: true
      t.decimal :hours, precision: 10, scale: 2, null: false
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.string :xero_invoice_id

      t.timestamps
    end
  end
end
