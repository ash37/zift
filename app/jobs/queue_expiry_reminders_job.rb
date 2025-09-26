class QueueExpiryRemindersJob < ApplicationJob
  queue_as :default

  def perform
    target_date = Date.current + 60.days
    start_time = target_date.beginning_of_day
    end_time   = target_date.end_of_day

    # Yellow expiry reminders
    User.where(yellow_expiry: start_time..end_time).find_each do |user|
      SendExpiryReminderJob.perform_later(user.id, :yellow)
    end

    # Blue expiry reminders
    User.where(blue_expiry: start_time..end_time).find_each do |user|
      SendExpiryReminderJob.perform_later(user.id, :blue)
    end
  end
end

