class CreateShifts < ActiveRecord::Migration[8.0]
  def change
    create_table :shifts do |t|
      t.references :user, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
      t.references :roster, null: false, foreign_key: true
      t.datetime :start_time
      t.datetime :end_time
      t.integer :recurrence_id

      t.timestamps
    end
  end
end
