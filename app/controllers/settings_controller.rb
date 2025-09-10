class SettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!

  def index
  end

  private
  def require_admin!
    redirect_to root_path, alert: "Unauthorized" unless current_user&.admin?
  end
end
