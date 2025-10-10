class CourseCompletion < ApplicationRecord
  belongs_to :user

  validates :course_slug, presence: true
end
