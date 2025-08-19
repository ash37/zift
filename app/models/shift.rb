# app/models/shift.rb
class Shift < ApplicationRecord
  # Add an attribute to control the validation
  attr_accessor :bypass_unavailability_validation

  belongs_to :roster
  belongs_to :user
  belongs_to :location
  belongs_to :area, optional: true
  has_many :timesheets, dependent: :destroy
  has_many :shift_answers, dependent: :destroy

  # Make the validation conditional
  validate :user_is_available, unless: :bypass_unavailability_validation

  validate :end_time_after_start_time
  validate :no_overlapping_shifts
  validate :duration_within_limits
  validate :not_in_past_for_published_roster

  def duration_in_hours
    return 0 unless start_time && end_time
    ((end_time - start_time) / 3600.0)
  end

  def determine_rate_name_for_time(time)
    date = time.to_date
    # Check for Public Holiday first, as it has the highest precedence.
    if roster.public_holiday?(date)
      return "Public Holiday"
    end

    case time.wday
    when 6 # Saturday
      "Saturday"
    when 0 # Sunday
      "Sunday"
    else # Weekday
      hour = time.hour
      if hour >= 22 # 10 PM or later
        "Weeknight (after 2 hours)"
      elsif hour >= 20 # 8 PM to 9:59 PM
        "Weeknight (first 2 hours)"
      else
        "Weekday"
      end
    end
  end


  # Questions applicable to this shift (via its area)
  def applicable_shift_questions
    return ShiftQuestion.none unless area_id
    ShiftQuestion.for_area(area)
  end

  def pre_shift_questions
    applicable_shift_questions.pre_shift
  end

  def post_shift_questions
    applicable_shift_questions.post_shift
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

  # This is the key validation method you requested. It is correct.
  def user_is_available
    return if user.blank? || start_time.blank? || end_time.blank?

    # 1. Finds unavailability requests for the correct user that are 'approved'
    unavailable = user.unavailability_requests.where(status: UnavailabilityRequest::STATUSES[:approved])
                      # 2. Checks if the request period overlaps with the new shift's time
                      .where("starts_at < ? AND ends_at > ?", end_time, start_time)
                      .exists?

    # 3. If an overlapping approved request exists, it adds an error and prevents saving
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
