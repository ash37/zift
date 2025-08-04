class Area < ApplicationRecord
  belongs_to :location
  has_many :shifts
end