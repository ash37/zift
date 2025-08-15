class CreateAreas < ActiveRecord::Migration[8.0]
  def change
    create_table :areas do |t|
      t.string :name
      t.string :export_code
      t.string :color
      t.references :location, null: false, foreign_key: true

      t.timestamps
    end

    add_reference :shifts, :area, null: true, foreign_key: true
  end
end
