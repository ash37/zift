class NotificationsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_manager_or_admin!

  def index
    @pending = UnavailabilityRequest
                 .where(status: UnavailabilityRequest::STATUSES[:pending])
                 .includes(:user)
                 .order(starts_at: :desc)
  end

  private

  def authorize_manager_or_admin!
    # Assumes `admin?` or `manager?` boolean helpers exist on User
    unless current_user&.respond_to?(:admin?) && current_user&.respond_to?(:manager?)
      redirect_to root_path and return
    end

    return if current_user.admin? || current_user.manager?

    redirect_to root_path
  end
end
