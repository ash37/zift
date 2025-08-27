class DashboardsController < ApplicationController
  before_action :authenticate_user!

  def index
    respond_to do |format|
      format.html
      format.json do
        selected_date = params[:date] ? Date.parse(params[:date]) : Date.current

        shifts = Shift.published
                      .where(location: current_user.location)
                      .where(date: selected_date)
                      .includes(:user, :role, :area, :location, :roster, :timesheet)

        render json: shifts.as_json(
          include: {
            user: { only: [ :id, :name, :email ] },
            role: { only: [ :id, :name ] },
            area: { only: [ :id, :name ] },
            location: { only: [ :id, :name ] },
            roster: { only: [ :id, :name ] },
            timesheet: { only: [ :id, :start_time, :end_time, :status ] }
          },
          only: [ :id, :start_time, :end_time, :notes, :date ]
        )
      end
    end
  end
end
