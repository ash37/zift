class DashboardsController < ApplicationController
  before_action :authenticate_user!, except: [ :index ]

  def index
    respond_to do |format|
      format.html
      format.json do
        # token auth path
        if params[:token].present?
          user = User.find_by_client_dashboard_token(params[:token])
          unless user
            render json: { error: "Invalid token" }, status: :unauthorized and return
          end
          # impersonate user for this request
          @current_user = user
        else
          authenticate_user!
          @current_user = current_user
        end

        selected_date = params[:date] ? Date.parse(params[:date]) : Date.current

        loc = if @current_user.respond_to?(:location) && @current_user.location.present?
                @current_user.location
        elsif @current_user.respond_to?(:locations)
                @current_user.locations.first
        end

        shifts = Shift.joins(:roster)
                      .where(rosters: { status: Roster::STATUSES[:published] })
                      .where(start_time: selected_date.beginning_of_day..selected_date.end_of_day)
                      .includes(:user, :area, :location, :roster, :timesheets)

        shifts = shifts.where(location: loc) if loc.present?

        render json: shifts.as_json(
          include: {
            user: { only: [ :id, :name, :email ] },
            area: { only: [ :id, :name ] },
            location: { only: [ :id, :name ] },
            roster: { only: [ :id ] },
            timesheets: { only: [ :id, :clock_in_at, :clock_out_at, :status, :notes ] }
          },
          only: [ :id, :start_time, :end_time, :notes ]
        )
      end
    end
  end
end
