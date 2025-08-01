class UnavailabilityRequest < ApplicationRecord
  belongs_to :user
  # enum status: { pending: 0, approved: 1, declined: 2 }

end
