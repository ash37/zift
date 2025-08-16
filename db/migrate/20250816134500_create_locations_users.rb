class CreateLocationsUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :locations_users, id: false do |t|
      t.belongs_to :location
      t.belongs_to :user
    end
  end
end
