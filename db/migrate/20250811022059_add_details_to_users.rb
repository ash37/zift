class AddDetailsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :status, :string
    add_column :users, :gender, :string
    add_column :users, :obtained_screening, :string
    add_column :users, :date_of_birth, :date
    add_column :users, :address, :string
    add_column :users, :suburb, :string
    add_column :users, :state, :string
    add_column :users, :postcode, :string
    add_column :users, :emergency_name, :string
    add_column :users, :emergency_phone, :string
    add_column :users, :disability_experience, :string
    add_column :users, :other_experience, :string
    add_column :users, :other_employment, :string
    add_column :users, :licence, :string
    add_column :users, :availability, :string
    add_column :users, :bio, :text
    add_column :users, :known_client, :string
    add_column :users, :resident, :string
    add_column :users, :education, :string
    add_column :users, :qualification, :string
    add_column :users, :bank_account, :string
    add_column :users, :bsb, :string
    add_column :users, :tfn, :string
    add_column :users, :training, :string
    add_column :users, :departure, :string
    add_column :users, :yellow_expiry, :string
    add_column :users, :blue_expiry, :string
    add_column :users, :tfn_threshold, :string
    add_column :users, :debt, :string
    add_column :users, :super_name, :string
    add_column :users, :super_number, :string
    add_column :users, :invitation_token, :string
    add_column :users, :invitation_sent_at, :datetime
  end
end
