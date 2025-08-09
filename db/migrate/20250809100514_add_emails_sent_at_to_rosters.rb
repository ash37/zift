class AddEmailsSentAtToRosters < ActiveRecord::Migration[8.0]
  def change
    add_column :rosters, :emails_sent_at, :datetime
  end
end
