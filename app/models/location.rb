class Location < ApplicationRecord
  has_many :areas
  has_many :shifts
end