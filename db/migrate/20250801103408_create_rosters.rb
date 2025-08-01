class CreateRosters < ActiveRecord::Migration[8.0]
  def change
    create_table :rosters do |t|
      t.date :starts_on
      t.integer :status

      t.timestamps
    end
  end
end
