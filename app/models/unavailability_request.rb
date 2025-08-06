# app/models/unavailability_request.rb
class UnavailabilityRequest < ApplicationRecord
  belongs_to :user

  STATUSES = {
    pending: 0,
    approved: 1,
    declined: 2
  }.freeze

  validates :status, inclusion: { in: STATUSES.values }
  validates :starts_at, :ends_at, :reason, presence: true

  # Helper methods to check status
  def pending?
    status == STATUSES[:pending]
  end

  def approved?
    status == STATUSES[:approved]
  end

  def declined?
    status == STATUSES[:declined]
  end

  # Helper method to get the status name as a string
  def status_name
    STATUSES.key(status).to_s.titleize
  end

  # FIX: Add this method to define what an "all day" request is.
  # It returns true if the start/end times span the entire day.
  def all_day?
    return false if starts_at.blank? || ends_at.blank?
    starts_at == starts_at.beginning_of_day && ends_at == ends_at.end_of_day
  end
end
