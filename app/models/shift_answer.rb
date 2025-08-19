class ShiftAnswer < ApplicationRecord
  belongs_to :shift
  belongs_to :timesheet
  belongs_to :shift_question
  belongs_to :user

  validates :answer_text, presence: true
  validates :shift_id, :timesheet_id, :shift_question_id, :user_id, presence: true

  # Helpers
  delegate :question_type, to: :shift_question
end
