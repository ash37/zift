class CreateUnavailabilityRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :unavailability_requests do |t|
      t.references :user, null: false, foreign_key: true
      t.datetime :starts_at
      t.datetime :ends_at
      t.string :reason
      t.integer :status

      t.timestamps
    end
  end
end
