class TimesheetExport < ApplicationRecord
  has_many :timesheet_export_lines, dependent: :destroy
  validates :idempotency_key, presence: true, uniqueness: true
  validates :pay_period_start, presence: true
  validates :pay_period_end, presence: true
  validates :status, presence: true
end
