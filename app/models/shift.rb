class Shift < ApplicationRecord
  belongs_to :user
  belongs_to :location
  belongs_to :roster
end
