class CreateCourseCompletions < ActiveRecord::Migration[7.1]
  def change
    create_table :course_completions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :course_slug, null: false
      t.integer :score
      t.boolean :passed, default: false, null: false
      t.datetime :completed_at

      t.timestamps
    end

    add_index :course_completions, [:user_id, :course_slug], unique: true
  end
end
