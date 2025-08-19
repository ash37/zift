class ShiftQuestion < ApplicationRecord
  # Constants (no enums)
  QUESTION_TYPES = {
    PRE_SHIFT:  "pre_shift",
    POST_SHIFT: "post_shift"
  }.freeze

  # Associations
  has_many :areas_shift_questions, class_name: "AreaShiftQuestion", dependent: :destroy
  has_many :areas, through: :areas_shift_questions

  has_many :shift_answers, dependent: :destroy

  # Validations
  validates :question_text, presence: true
  validates :question_type, presence: true, inclusion: { in: QUESTION_TYPES.values }
  validates :display_order, numericality: { only_integer: true }

  # Scopes
  scope :active,    -> { where(is_active: true) }
  scope :ordered,   -> { order(:display_order, :id) }
  scope :pre_shift, -> { where(question_type: QUESTION_TYPES[:PRE_SHIFT]) }
  scope :post_shift, -> { where(question_type: QUESTION_TYPES[:POST_SHIFT]) }

  # Helper to fetch questions for a given area
  def self.for_area(area)
    joins(:areas).where(areas: { id: area.id }).active.ordered.distinct
  end
end
