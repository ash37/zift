class PushSubscription < ApplicationRecord
  belongs_to :user

  scope :active, -> { where(active: true) }

  validates :endpoint, presence: true, uniqueness: true
  validates :p256dh, :auth, presence: true
end

