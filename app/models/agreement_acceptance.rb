class AgreementAcceptance < ApplicationRecord
  belongs_to :user
  belongs_to :agreement

  validates :signed_name, presence: true
  validates :signed_at, presence: true
  validates :content_hash, presence: true
end

