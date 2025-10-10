class AuditController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_audit_access

  def index
    @recent_users = User.order(created_at: :desc).limit(10)
    @active_employees = User.where(role: User::ROLES[:employee]).order(:name)
    @active_locations = Location.ordered_by_name.active_status
    @recent_locations = Location.order(created_at: :desc).limit(10)
    @recent_incidents = Incident.order(created_at: :desc).limit(10)
  end

  private

  def authorize_audit_access
    unless current_user.admin? || current_user.auditor?
      redirect_to root_path, alert: "You are not authorized to view that page."
    end
  end
end
