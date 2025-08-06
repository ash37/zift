class UnavailabilityRequest < ApplicationRecord
  belongs_to :user

  STATUSES = {
    pending: 0,
    approved: 1,
    declined: 2
  }.freeze

  validates :status, inclusion: { in: STATUSES.values }

  def pending?
    status == STATUSES[:pending]
  end

  def approved?
    status == STATUSES[:approved]
  end

  def declined?
    status == STATUSES[:declined]
  end

  def status_name
    STATUSES.key(status).to_s.titleize
  end
end
