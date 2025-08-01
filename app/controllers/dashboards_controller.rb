class DashboardsController < ApplicationController
  before_action :authenticate_user!

  def index
    # Future logic: show today's shifts, pending requests, etc.
  end
end
