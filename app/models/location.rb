class Location < ApplicationRecord
  has_many :shifts
  has_and_belongs_to_many :users
  has_many :areas, dependent: :destroy

  accepts_nested_attributes_for :areas, allow_destroy: true, reject_if: :all_blank

  validates :name, presence: true
end
