class RemoveUnusedColumnsFromIncidents < ActiveRecord::Migration[7.1]
  def change
    change_table :incidents, bulk: true do |t|
      t.remove :incident_country
      t.remove :incident_address_line2
      t.remove :reported_to
      t.remove :other_clients
    end
  end
end
