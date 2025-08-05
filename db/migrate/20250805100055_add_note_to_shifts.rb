class AddNoteToShifts < ActiveRecord::Migration[8.0]
  def change
    add_column :shifts, :note, :text
  end
end
