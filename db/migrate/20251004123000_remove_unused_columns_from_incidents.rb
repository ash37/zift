class RemoveUnusedColumnsFromIncidents < ActiveRecord::Migration[7.1]
  def up
    remove_column :incidents, :incident_country if column_exists?(:incidents, :incident_country)
    remove_column :incidents, :incident_address_line2 if column_exists?(:incidents, :incident_address_line2)
    remove_column :incidents, :reported_to if column_exists?(:incidents, :reported_to)
    remove_column :incidents, :other_clients if column_exists?(:incidents, :other_clients)
  end

  def down
    add_column :incidents, :incident_country, :string unless column_exists?(:incidents, :incident_country)
    add_column :incidents, :incident_address_line2, :string unless column_exists?(:incidents, :incident_address_line2)
    add_column :incidents, :reported_to, :text unless column_exists?(:incidents, :reported_to)
    add_column :incidents, :other_clients, :text unless column_exists?(:incidents, :other_clients)
  end
end
