class Comment < ApplicationRecord
  belongs_to :user
  belongs_to :commentable, polymorphic: true
  belongs_to :edited_by, class_name: 'User', optional: true

  has_many_attached :files

  validates :body, presence: true
end
