class Roster < ApplicationRecord
  has_many :shifts
  has_many :users, through: :shifts
  has_many :locations, through: :shifts

  serialize :public_holidays, coder: JSON, type: Array

  STATUSES = {
  draft: 0,
  published: 1
}.freeze


  validates :starts_on, presence: true
  validates :status, inclusion: { in: STATUSES.values }

  def draft?
    status == STATUSES[:draft]
  end

  def published?
    status == STATUSES[:published]
  end

  def status_label
    STATUSES.key(status).to_s.humanize
  end

  def shifts_by_day
    shifts.group_by { |shift| shift.start_time.to_date }
  end

  def public_holiday?(date)
    public_holidays.include?(date)
  end
end
