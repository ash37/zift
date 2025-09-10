class LocationAgreementAcceptance < ApplicationRecord
  belongs_to :location
  belongs_to :agreement

  before_validation :ensure_token, on: :create

  validates :token, presence: true, uniqueness: true
  validates :content_hash, presence: true

  def signed?
    signed_at.present?
  end

  private
  def ensure_token
    self.token ||= SecureRandom.urlsafe_base64(24)
  end
end
