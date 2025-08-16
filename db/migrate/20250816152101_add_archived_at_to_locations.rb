class AddArchivedAtToLocations < ActiveRecord::Migration[7.1]
  def change
    add_column :locations, :archived_at, :datetime
  end
end
