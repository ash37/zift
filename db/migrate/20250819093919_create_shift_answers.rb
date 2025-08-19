class CreateShiftAnswers < ActiveRecord::Migration[7.1]
  def change
    create_table :shift_answers do |t|
      t.text       :answer_text,     null: false
      t.references :shift,           null: false, foreign_key: true
      t.references :timesheet,       null: false, foreign_key: true
      t.references :shift_question,  null: false, foreign_key: true
      t.references :user,            null: false, foreign_key: true  # who answered

      t.timestamps
    end

    add_index :shift_answers, [ :timesheet_id, :shift_question_id ], name: "idx_answers_timesheet_question"
    add_index :shift_answers, [ :shift_id, :shift_question_id ],     name: "idx_answers_shift_question"
  end
end
