class ApplicationController < ActionController::Base
  include Devise::Controllers::Helpers
  helper_method :current_user, :user_signed_in?

  def after_sign_in_path_for(resource)
    dashboards_path
  end

  def after_sign_out_path_for(resource_or_scope)
    root_path
  end
end
