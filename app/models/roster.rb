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
  validates :starts_on, uniqueness: true
  validate :starts_on_must_be_wednesday
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

  private
  def starts_on_must_be_wednesday
    return if starts_on.blank?
    # In Ruby, wday: 0=Sunday, 3=Wednesday
    errors.add(:starts_on, "must be a Wednesday") unless starts_on.wday == 3
  end
end
