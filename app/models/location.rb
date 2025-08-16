class Location < ApplicationRecord
  has_many :shifts
  has_and_belongs_to_many :users

  validates :name, presence: true
end
