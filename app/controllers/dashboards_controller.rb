class DashboardsController < ApplicationController
  before_action :authenticate_user!

  def index
    respond_to do |format|
      format.html
      format.json do
        selected_date = params[:date] ? Date.parse(params[:date]) : Date.current
        # Determine the client's single location (clients have many locations)
        loc = if current_user.respond_to?(:location) && current_user.location.present?
                current_user.location
        elsif current_user.respond_to?(:locations)
                current_user.locations.first
        end

        shifts = Shift.joins(:roster)
                      .where(rosters: { status: Roster::STATUSES[:published] })
                      .where(start_time: selected_date.all_day)
                      .includes(:user, :area, :location, :roster, :timesheets)

        shifts = shifts.where(location: loc) if loc.present?

        render json: shifts.as_json(
          include: {
            user: { only: [ :id, :name, :email ] },
            area: { only: [ :id, :name ] },
            location: { only: [ :id, :name ] },
            roster: { only: [ :id, :name ] },
            timesheets: { only: [ :id, :clock_in_at, :clock_out_at, :status, :notes ] }
          },
          only: [ :id, :start_time, :end_time, :notes ]
        )
      end
    end
  end
end
