class ApplicationController < ActionController::Base
  helper_method :pending_unavailability_count

  def pending_unavailability_count
    # Only show a count for admins/managers who are signed in
    return 0 unless user_signed_in? && (current_user.admin? || current_user.manager?)

    UnavailabilityRequest.where(status: UnavailabilityRequest::STATUSES[:pending]).count
  end
  before_action :authenticate_user!
  skip_before_action :authenticate_user!, if: -> { controller_name == "welcome" && action_name == "index" }
  include Devise::Controllers::Helpers
  helper_method :current_user, :user_signed_in?

  def after_sign_in_path_for(resource)
    dashboards_path
  end

  def after_sign_out_path_for(resource_or_scope)
    root_path
  end
end
