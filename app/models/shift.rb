# app/models/shift.rb
class Shift < ApplicationRecord
  default_scope { order(:start_time, :end_time, :id) }
  # Add attributes to control validations
  attr_accessor :bypass_unavailability_validation
  attr_accessor :bypass_past_published_validation
  attr_accessor :bypass_overlap_validation
  attr_reader :unavailability_conflict

  belongs_to :roster,   inverse_of: :shifts
  belongs_to :user,     inverse_of: :shifts
  belongs_to :location, inverse_of: :shifts
  belongs_to :area,     optional: true, inverse_of: :shifts
  has_many :timesheets, dependent: :destroy
  has_many :shift_answers, dependent: :destroy

  before_validation :ensure_area_matches_location

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

  def ensure_area_matches_location
    return if area_id.blank? || location_id.blank?
    return unless area && area.respond_to?(:location_id)

    if area.location_id != location_id
      Rails.logger.warn("[Shift] Clearing area_id=#{area_id} because it does not belong to location_id=#{location_id}")
      self.area_id = nil
    end
  end

  def end_time_after_start_time
    return if end_time.blank? || start_time.blank?
    if end_time <= start_time
      errors.add(:end_time, "must be after the start time")
    end
  end

  def no_overlapping_shifts
    return if user.blank? || start_time.blank? || end_time.blank?
    return if bypass_overlap_validation

    overlapping = user.shifts.where.not(id: id)
                      .where("start_time < ? AND end_time > ?", end_time, start_time)
                      .exists?

    if overlapping
      errors.add(:base, "User is already scheduled for an overlapping shift.")
    end
  end

  # Previously, this validation added an error and prevented saving when the user
  # had overlapping approved unavailability. We now allow saving and surface
  # the conflict in the UI (red badge on the shift) instead.
  def user_is_available
    return if user.blank? || start_time.blank? || end_time.blank?

    conflict = user.unavailability_requests
                   .where(status: UnavailabilityRequest::STATUSES[:approved])
                   .where("starts_at < ? AND ends_at > ?", end_time, start_time)
                   .exists?

    # Expose a non-persistent flag for callers if needed (does not block save)
    @unavailability_conflict = true if conflict

    # Do NOT add errors; allow the record to save. UI indicates conflict.
    true
  end

  def duration_within_limits
    return if start_time.blank? || end_time.blank?

    duration = (end_time - start_time) / 1.hour
    if duration < 0.25 || duration > 9
      errors.add(:base, "Shift duration must be between 15 minutes and 9 hours.")
    end
  end

  def not_in_past_for_published_roster
    return if roster.blank? || start_time.blank? || bypass_past_published_validation

    if roster.published? && start_time < Time.current
      errors.add(:base, "Cannot schedule a shift in the past for a published roster.")
    end
  end

  before_save :log_area_and_note_changes, if: -> { ENV["SHIFT_DEBUG"] == "1" }

  private

  def log_area_and_note_changes
    if will_save_change_to_area_id? || will_save_change_to_note?
      Rails.logger.info("[ShiftDebug] Shift##{id || 'new'} user=#{user_id} " \
                        "loc=#{location_id} area: #{area_id_before_last_save.inspect}→#{area_id.inspect} " \
                        "note: #{note_before_last_save.inspect}→#{note.inspect}")
    end
  end
end
