# app/models/shift.rb
class Shift < ApplicationRecord
  belongs_to :roster
  belongs_to :user
  belongs_to :location
  belongs_to :area, optional: true
  has_many :timesheets, dependent: :destroy

  def duration_in_hours
    return 0 unless start_time && end_time
    ((end_time - start_time) / 3600.0)
  end
end
