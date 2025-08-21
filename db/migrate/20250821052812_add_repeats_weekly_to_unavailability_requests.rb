class AddRepeatsWeeklyToUnavailabilityRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :unavailability_requests, :repeats_weekly, :boolean, default: false, null: false
    add_index  :unavailability_requests, :repeats_weekly
  end
end
