class CreateTimesheets < ActiveRecord::Migration[8.0]
  def change
    create_table :timesheets do |t|
      t.references :user, null: false, foreign_key: true
      t.references :shift, null: false, foreign_key: true
      t.datetime :clock_in_at
      t.datetime :clock_out_at
      t.integer :duration
      t.integer :status

      t.timestamps
    end
  end
end
