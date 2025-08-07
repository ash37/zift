class ReportsController < ApplicationController
  def index
    @locations = Location.all
    @selected_location_id = params[:location_id]

    if current_user.admin? || current_user.manager?
      @timesheets = Timesheet.where.not(notes: [ nil, "" ])
    else
      @timesheets = current_user.timesheets.where.not(notes: [ nil, "" ])
    end

    @timesheets = @timesheets.includes(shift: [ :location, :user ]).order(created_at: :desc)

    if @selected_location_id.present?
      @timesheets = @timesheets.joins(shift: :location).where(locations: { id: @selected_location_id })
    end
  end
end
