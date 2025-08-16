class RemoveLocationIdFromUsers < ActiveRecord::Migration[7.1]
  def change
    remove_reference :users, :location, foreign_key: true
  end
end
