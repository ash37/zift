class XeroConnection < ApplicationRecord
  validates :tenant_id, presence: true, uniqueness: true
  validates :access_token, presence: true
  validates :refresh_token, presence: true
  validates :scopes, presence: true
  validates :expires_at, presence: true
end
