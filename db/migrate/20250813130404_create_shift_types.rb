class CreateShiftTypes < ActiveRecord::Migration[8.0]
  def change
    create_table :shift_types do |t|
      t.string :name, null: false
      t.string :xero_earnings_rate_id

      t.timestamps
    end

    add_index :shift_types, :name, unique: true
  end
end
