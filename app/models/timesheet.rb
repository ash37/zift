class Timesheet < ApplicationRecord
  belongs_to :user
  belongs_to :shift, optional: true
  belongs_to :area, optional: true
  has_many :invoice_export_lines, dependent: :destroy
  has_many :shift_answers, dependent: :destroy

  accepts_nested_attributes_for :shift
  accepts_nested_attributes_for :shift_answers,
    allow_destroy: false,
    reject_if: proc { |attrs| attrs["answer_text"].blank? }

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
    return "Auto" if auto_clock_off? && (status.nil? || status == STATUSES[:pending])
    return STATUSES.key(status).to_s if status.present? && STATUSES.value?(status)
    return "Started" if started?
    "pending"
  end

  # Returns true if this in-progress timesheet should block the user from
  # starting a new unscheduled shift. We allow creating a new one when the
  # associated shift ended more than 4 hours ago (the auto-clock-off job will
  # take care of closing it soon), but we still block if the shift is ongoing
  # or its end time is unknown.
  def blocks_new_unscheduled_shift?
    return false if clock_out_at.present?

    shift_end = shift&.end_time
    shift_end.nil? || shift_end > 4.hours.ago
  end

  def duration_in_hours
    return 0 unless clock_in_at && clock_out_at
    ((clock_out_at - clock_in_at) / 3600.0)
  end

  def rostered_hours
    shift.duration_in_hours
  end

  # Fetch unanswered questions of a given type for this timesheet/shift
  def unanswered_questions(question_type:)
    asked = shift_answers.includes(:shift_question).map(&:shift_question_id)
    scope = shift.applicable_shift_questions.where(question_type: question_type)
    asked.present? ? scope.where.not(id: asked) : scope
  end

  private

  def clock_out_after_clock_in
    return if clock_out_at.blank? || clock_in_at.blank?

    if clock_out_at <= clock_in_at
      errors.add(:clock_out_at, "must be after the clock in time")
    end
  end
end
