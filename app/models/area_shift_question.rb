class AreaShiftQuestion < ApplicationRecord
  self.table_name = "areas_shift_questions"

  belongs_to :area
  belongs_to :shift_question

  validates :area_id, uniqueness: { scope: :shift_question_id }
end
