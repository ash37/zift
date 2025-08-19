class Area < ApplicationRecord
  belongs_to :location
  has_many :shifts
  has_many :area_shift_questions, dependent: :destroy
  has_many :shift_questions, through: :area_shift_questions

  # Convenience to get only active, ordered questions
  def ordered_active_shift_questions
    shift_questions.active.ordered
  end
end
