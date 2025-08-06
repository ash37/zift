class AutoClockOutJob < ApplicationJob
  queue_as :default

  def perform
    # Find timesheets that are still clocked in and where the shift's
    # end_time is more than 4 hours in the past.
    Timesheet.where(clock_out_at: nil).joins(:shift).where("shifts.end_time < ?", 4.hours.ago).find_each do |timesheet|
      timesheet.update(
        clock_out_at: timesheet.shift.end_time,
        auto_clock_off: true,
        notes: (timesheet.notes.presence || "") + " Automatically clocked out."
      )
    end
  end
end
