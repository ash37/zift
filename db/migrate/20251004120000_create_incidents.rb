class CreateIncidents < ActiveRecord::Migration[7.1]
  def change
    create_table :incidents do |t|
      t.string :reporter_first_name, null: false
      t.string :reporter_last_name, null: false
      t.string :reporter_email, null: false
      t.string :category, null: false
      t.text :details, null: false
      t.date :incident_date, null: false
      t.time :incident_time
      t.string :incident_address_line1, null: false
      t.string :incident_suburb, null: false
      t.string :incident_state, null: false
      t.string :incident_postcode, null: false
      t.text :witnesses
      t.text :immediate_action
      t.string :police_notified
      t.string :client_first_name
      t.string :client_last_name
      t.string :client_behaviour
      t.string :injuries_sustained
      t.string :treatment_required
      t.text :property_damage

      t.timestamps
    end
  end
end
