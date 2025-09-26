class AddEditTrackingToComments < ActiveRecord::Migration[8.0]
  def change
    add_column :comments, :edited_at, :datetime
    add_column :comments, :edited_by_id, :bigint
    add_index  :comments, :edited_by_id
  end
end

