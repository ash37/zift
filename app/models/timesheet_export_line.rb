class TimesheetExportLine < ApplicationRecord
  belongs_to :timesheet_export
  belongs_to :user

  validates :earnings_rate_id, presence: true
  validates :daily_units, presence: true
end
