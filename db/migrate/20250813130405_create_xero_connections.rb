class CreateXeroConnections < ActiveRecord::Migration[8.0]
  def change
    create_table :xero_connections do |t|
      t.string :tenant_id, null: false
      t.string :access_token, null: false
      t.string :refresh_token, null: false
      t.string :scopes, null: false
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :xero_connections, :tenant_id, unique: true
  end
end
