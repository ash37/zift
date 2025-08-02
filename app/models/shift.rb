class Shift < ApplicationRecord
  belongs_to :roster
  belongs_to :user
  belongs_to :location
end
