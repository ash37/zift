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
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :course_completions, dependent: :destroy

  # Employee compliance documents
  has_one_attached :ndis_screening_card
  has_many_attached :id_documents
  has_one_attached :ndis_orientation_certificate
  has_one_attached :qcare_induction_certificate

  attr_accessor :application_submission

  MAX_ATTACHMENT_SIZE = 12.megabytes
  ALLOWED_CONTENT_TYPES = %w[
    image/jpeg image/png image/webp image/heic image/heif application/pdf
  ].freeze

  validate :validate_uploads

  def validate_uploads
    [
      [:ndis_screening_card, ndis_screening_card],
      [:ndis_orientation_certificate, ndis_orientation_certificate],
      [:qcare_induction_certificate, qcare_induction_certificate]
    ].each do |name, attachment|
      next unless attachment.attached?
      validate_blob(attachment.blob, name: name)
    end

    id_documents.each do |doc|
      validate_blob(doc.blob, name: :id_documents)
    end
  end

  def validate_blob(blob, name:)
    return unless blob
    unless ALLOWED_CONTENT_TYPES.include?(blob.content_type)
      errors.add(name, "must be an image (JPEG/PNG/WEBP/HEIC) or PDF")
    end
    if blob.byte_size > MAX_ATTACHMENT_SIZE
      errors.add(name, "is too large (max #{(MAX_ATTACHMENT_SIZE / 1.megabyte).to_i}MB)")
    end
  end

  ROLES = {
    employee: 0,
    manager: 1,
    admin: 2,
    client: 3,
    auditor: 4
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
  scope :ordered_by_name, -> { order(Arel.sql('LOWER(name) ASC')) }

  with_options if: :application_submission? do
    validates :name, :email, :phone, :date_of_birth, :suburb, :postcode,
              :obtained_screening, :disability_experience,
              :other_employment, :licence, :availability, presence: true
  end

  # Archiving
  default_scope { where(archived_at: nil) }
  scope :archived, -> { unscope(where: :archived_at).where.not(archived_at: nil) }
  scope :with_archived, -> { unscope(where: :archived_at) }

  def archived?
    archived_at.present?
  end

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

  def auditor?
    role == ROLES[:auditor]
  end

  def course_completion_for(slug)
    course_completions.find_by(course_slug: slug)
  end

  def course_completed?(slug)
    completion = course_completion_for(slug)
    completion&.passed?
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

  def application_submission?
    ActiveModel::Type::Boolean.new.cast(application_submission)
  end

  # This method is called by Devise to check if a password is required.
  def password_required?
    # Don't require a password if an invitation is being sent.
    return false if invitation_token_changed? && invitation_token.present?

    # Require password if it's a new record OR if password fields are filled in.
    !persisted? || password.present? || password_confirmation.present?
  end
end
