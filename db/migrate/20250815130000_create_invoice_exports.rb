class CreateInvoiceExports < ActiveRecord::Migration[8.0]
  def change
    create_table :invoice_exports do |t|
      t.string :idempotency_key, null: false
      t.string :status, null: false, default: 'pending'
      t.integer :exported_count, default: 0
      t.integer :total_count, default: 0
      t.text :error_blob

      t.timestamps
    end

    add_index :invoice_exports, :idempotency_key, unique: true
  end
end
