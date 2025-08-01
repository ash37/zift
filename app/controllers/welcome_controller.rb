class WelcomeController < ApplicationController
  before_action :authenticate_user!
  def index
    redirect_to dashboards_path if user_signed_in?
  end
end
