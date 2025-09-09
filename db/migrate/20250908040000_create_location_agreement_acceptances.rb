class CreateLocationAgreementAcceptances < ActiveRecord::Migration[8.0]
  def change
    create_table :location_agreement_acceptances do |t|
      t.references :location,  null: false, foreign_key: true
      t.references :agreement, null: false, foreign_key: true
      t.string  :email
      t.string  :signed_name
      t.datetime :signed_at
      t.string  :ip_address
      t.string  :user_agent
      t.string  :content_hash, null: false
      t.string  :token, null: false
      t.datetime :emailed_at
      t.timestamps
    end
    add_index :location_agreement_acceptances, :token, unique: true
    add_index :location_agreement_acceptances, [:location_id, :agreement_id]
  end
end

