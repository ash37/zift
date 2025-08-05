class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  belongs_to :location, optional: true
  has_many :shifts, dependent: :destroy
  has_many :timesheets, dependent: :destroy

  ROLES = {
    employee: 0,
    manager: 1,
    admin: 2
  }.freeze

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

  # Used in views to allow role assignment only for admins
  def role_admin?
    admin?
  end
end
