class Location < ApplicationRecord
  has_many :shifts
  has_and_belongs_to_many :users
  has_many :areas, dependent: :destroy
  has_many :shift_questions, through: :areas
  has_one_attached :support_plan
  has_one_attached :risk_assessment
  has_many :comments, as: :commentable, dependent: :destroy

  accepts_nested_attributes_for :areas, allow_destroy: true, reject_if: :all_blank

  validates :name, presence: true

  default_scope { where(archived_at: nil) }

  scope :archived, -> { unscope(where: :archived_at).where.not(archived_at: nil) }
  scope :with_archived, -> { unscope(where: :archived_at) }
  scope :ordered_by_name, -> { order(Arel.sql('LOWER(name) ASC')) }

  def archived?
    archived_at.present?
  end
end
