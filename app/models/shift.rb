# app/models/shift.rb
class Shift < ApplicationRecord
  belongs_to :roster
  belongs_to :user
  belongs_to :location
  belongs_to :area, optional: true
  has_many :timesheets, dependent: :destroy

  validate :end_time_after_start_time
  validate :no_overlapping_shifts
  validate :user_is_available
  validate :duration_within_limits
  validate :not_in_past_for_published_roster

  def duration_in_hours
    return 0 unless start_time && end_time
    ((end_time - start_time) / 3600.0)
  end

  private

  def end_time_after_start_time
    return if end_time.blank? || start_time.blank?
    if end_time <= start_time
      errors.add(:end_time, "must be after the start time")
    end
  end

  def no_overlapping_shifts
    return if user.blank? || start_time.blank? || end_time.blank?

    overlapping = user.shifts.where.not(id: id)
                      .where("start_time < ? AND end_time > ?", end_time, start_time)
                      .exists?

    if overlapping
      errors.add(:base, "User is already scheduled for an overlapping shift.")
    end
  end

  def user_is_available
    return if user.blank? || start_time.blank? || end_time.blank?

    unavailable = user.unavailability_requests.where(status: UnavailabilityRequest::STATUSES[:approved])
                      .where("starts_at < ? AND ends_at > ?", end_time, start_time)
                      .exists?

    if unavailable
      errors.add(:base, "User has an approved unavailability request during this time.")
    end
  end

  def duration_within_limits
    return if start_time.blank? || end_time.blank?

    duration = (end_time - start_time) / 1.hour
    if duration < 0.5 || duration > 11
      errors.add(:base, "Shift duration must be between 0.5 and 11 hours.")
    end
  end

  def not_in_past_for_published_roster
    return if roster.blank? || start_time.blank?

    if roster.published? && start_time < Time.current
      errors.add(:base, "Cannot schedule a shift in the past for a published roster.")
    end
  end
end
