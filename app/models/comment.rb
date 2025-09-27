class Comment < ApplicationRecord
  belongs_to :user
  belongs_to :commentable, polymorphic: true
  belongs_to :edited_by, class_name: 'User', optional: true

  has_many_attached :files

  validate :body_or_files_present

  private
  def body_or_files_present
    if body.to_s.strip.blank? && !files.attached?
      errors.add(:base, "Please add a comment or attach a file.")
    end
  end
end
