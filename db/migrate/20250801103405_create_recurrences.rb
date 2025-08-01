class CreateRecurrences < ActiveRecord::Migration[8.0]
  def change
    create_table :recurrences do |t|
      t.string :frequency
      t.integer :interval
      t.date :ends_on

      t.timestamps
    end
  end
end
