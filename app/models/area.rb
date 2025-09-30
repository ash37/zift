class Area < ApplicationRecord
  TRAVEL_NAME = "travel".freeze

  attribute :show_timesheet_notes, :boolean, default: true
  attribute :show_timesheet_travel, :boolean, default: true
  belongs_to :location
  has_many :shifts
  has_many :area_shift_questions, dependent: :destroy
  has_many :shift_questions, through: :area_shift_questions

  scope :excluding_travel, -> { where.not("LOWER(TRIM(COALESCE(name, ''))) = ?", TRAVEL_NAME) }

  def travel?
    name.to_s.strip.casecmp?(TRAVEL_NAME)
  end

  # Convenience to get only active, ordered questions
  def ordered_active_shift_questions
    shift_questions.active.ordered
  end
end
