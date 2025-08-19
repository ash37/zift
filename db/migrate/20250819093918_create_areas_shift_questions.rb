class CreateAreasShiftQuestions < ActiveRecord::Migration[7.1]
  def change
    create_table :areas_shift_questions do |t|
      t.references :area,           null: false, foreign_key: true
      t.references :shift_question, null: false, foreign_key: true

      t.timestamps
    end

    add_index :areas_shift_questions, [ :area_id, :shift_question_id ], unique: true, name: "idx_areas_shift_questions_uniqueness"
  end
end
