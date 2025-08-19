class CreateShiftQuestions < ActiveRecord::Migration[7.1]
  def change
    create_table :shift_questions do |t|
      t.string  :question_text,  null: false
      t.string  :question_type,  null: false   # use constants in the model (no enum)
      t.integer :display_order,  null: false, default: 0
      t.boolean :is_mandatory,   null: false, default: false
      t.boolean :is_active,      null: false, default: true

      t.timestamps
    end

    add_index :shift_questions, :question_type
    add_index :shift_questions, :is_active
    add_index :shift_questions, :display_order
  end
end
