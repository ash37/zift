class AddPushSubscriptionsAndReminderSends < ActiveRecord::Migration[7.1]
  def change
    create_table :push_subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.text :endpoint, null: false
      t.text :p256dh, null: false
      t.text :auth, null: false
      t.boolean :active, null: false, default: true
      t.string :user_agent
      t.string :platform
      t.datetime :last_used_at
      t.timestamps
    end
    add_index :push_subscriptions, :endpoint, unique: true

    create_table :reminder_sends do |t|
      t.references :user, null: false, foreign_key: true
      t.references :shift, null: false, foreign_key: true
      t.string :kind, null: false
      t.datetime :sent_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }
      t.timestamps
    end
    add_index :reminder_sends, [:user_id, :shift_id, :kind], unique: true, name: 'index_reminder_sends_unique'
  end
end

