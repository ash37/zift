class Timesheet < ApplicationRecord
  belongs_to :user
  belongs_to :shift

  accepts_nested_attributes_for :shift

  STATUSES = {
    pending: 0,
    approved: 1,
    rejected: 2
  }.freeze

  validates :status, inclusion: { in: STATUSES.values }

  def pending?
    status == STATUSES[:pending]
  end

  def approved?
    status == STATUSES[:approved]
  end

  def rejected?
    status == STATUSES[:rejected]
  end

  def clocked_out?
    clock_out_at.present?
  end

  def status_name
    STATUSES.key(status).to_s
  end

  def duration_in_hours
    return 0 unless clock_in_at && clock_out_at
    ((clock_out_at - clock_in_at) / 3600.0)
  end

  def rostered_hours
    shift.duration_in_hours
  end
end
