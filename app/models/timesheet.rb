class Timesheet < ApplicationRecord
  belongs_to :user
  belongs_to :shift

  accepts_nested_attributes_for :shift

  STATUSES = {
    pending: 0,
    approved: 1,
    rejected: 2
  }.freeze

  # Scope to find unapproved timesheets (status is nil or pending)
  scope :unapproved, -> {
    vals = [ nil ]
    vals << self::STATUS_PENDING if const_defined?(:STATUS_PENDING)
    where(status: vals)
  }

  validates :status, inclusion: { in: STATUSES.values }
  validate :clock_out_after_clock_in

  def pending?
    status == STATUSES[:pending]
  end

  def approved?
    status == STATUSES[:approved]
  end

  def rejected?
    status == STATUSES[:rejected]
  end

  def started?
    clock_in_at.present? && clock_out_at.blank?
  end

  def clocked_out?
    clock_out_at.present?
  end

  def status_name
    if auto_clock_off?
      "Auto"
    elsif started?
      "Started"
    else
      STATUSES.key(status).to_s
    end
  end

  def duration_in_hours
    return 0 unless clock_in_at && clock_out_at
    ((clock_out_at - clock_in_at) / 3600.0)
  end

  def rostered_hours
    shift.duration_in_hours
  end

  private

  def clock_out_after_clock_in
    return if clock_out_at.blank? || clock_in_at.blank?

    if clock_out_at <= clock_in_at
      errors.add(:clock_out_at, "must be after the clock in time")
    end
  end
end
