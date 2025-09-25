class QueueShiftRemindersJob < ApplicationJob
  queue_as :default

  def perform
    minutes = ENV.fetch('SHIFT_REMINDER_MINUTES', '30').to_i
    now = Time.current
    window_start = now + minutes.minutes
    window_end = window_start + 59.seconds

    shifts = Shift.where(start_time: window_start..window_end)
    shifts.find_each do |shift|
      next unless shift.user
      # Idempotency check
      already = ReminderSend.where(user_id: shift.user_id, shift_id: shift.id, kind: ReminderSend::KINDS[:pre_start_30]).exists?
      next if already
      SendShiftReminderJob.perform_later(shift.user_id, shift.id)
    end
  end
end

