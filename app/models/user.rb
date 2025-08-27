class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  def self.serialize_from_session(key, salt)
    record = to_adapter.get(key)
    record if record && record.authenticatable_salt == salt
  end

  def self.serialize_into_session(record)
    [ record.to_key, record.authenticatable_salt ]
  end

  has_and_belongs_to_many :locations
  has_many :shifts, dependent: :destroy
  has_many :timesheets, dependent: :destroy
  has_many :shift_answers, dependent: :nullify
  has_many :unavailability_requests, dependent: :destroy
  has_many :timesheet_export_lines

  ROLES = {
    employee: 0,
    manager: 1,
    admin: 2,
    client: 3
  }.freeze

  STATUSES = {
    applicant: "applicant",
    contacted: "contacted",
    employee: "employee",
    ended: "ended"
  }.freeze

  validates :status, inclusion: { in: STATUSES.values }, allow_nil: true

  scope :applicants, -> { where(status: STATUSES[:applicant]) }
  scope :employees, -> { where(status: STATUSES[:employee]) }
  scope :contacted, -> { where(status: STATUSES[:contacted]) }
  scope :ended, -> { where(status: STATUSES[:ended]) }

  def role_name
    ROLES.key(role)&.to_s&.titleize || "—"
  end

  def admin?
    role == ROLES[:admin]
  end

  def manager?
    role == ROLES[:manager]
  end

  def employee?
    role == ROLES[:employee]
  end

  def client?
    role == ROLES[:client]
  end

  # Used in views to allow role assignment only for admins
  def role_admin?
    admin?
  end

  def first_name
    name.split.first
  end

  def last_name
    name.split.last
  end

  # Signed token for calling /client_dashboard.json as this user
  # Rotate by changing an attribute that invalidates signed_id (e.g., updated_at)
  def client_dashboard_token
    signed_id(purpose: :client_dashboard, expires_in: 1.year)
  end

  # Resolve a user from a client-dashboard token
  def self.find_by_client_dashboard_token(token)
    return nil if token.blank?
    find_signed(token, purpose: :client_dashboard)
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveSupport::MessageEncryptor::InvalidMessage
    nil
  end

  protected

  # This method is called by Devise to check if a password is required.
  def password_required?
    # Don't require a password if an invitation is being sent.
    return false if invitation_token_changed? && invitation_token.present?

    # Require password if it's a new record OR if password fields are filled in.
    !persisted? || password.present? || password_confirmation.present?
  end
end
