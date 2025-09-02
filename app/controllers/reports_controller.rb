class ReportsController < ApplicationController
  before_action :authenticate_user!
  def index
    @locations = Location.all
    @selected_location_id = params[:location_id]

    # Determine the 7-day window (Wednesday to Tuesday)
    anchor_date = params[:week].present? ? Date.parse(params[:week]) : Time.zone.today
    days_since_wed = (anchor_date.wday - 3) % 7  # 0=Sun, 3=Wed
    week_start_date = anchor_date - days_since_wed
    @week_start = week_start_date.beginning_of_day
    @week_end   = (week_start_date + 6).end_of_day

    # Useful for the view navigation
    @current_week_start = week_start_date
    @prev_week_start    = week_start_date - 7
    @next_week_start    = week_start_date + 7

    # Cap navigation at the current week (do not allow browsing into the future)
    today = Time.zone.today
    days_since_wed_today = (today.wday - 3) % 7
    @max_week_start = (today - days_since_wed_today)

    if current_user.admin? || current_user.manager?
      @timesheets = Timesheet.where.not(notes: [ nil, "" ])
    else
      @timesheets = current_user.timesheets.where.not(notes: [ nil, "" ])
    end

    # Limit to selected week window (by timesheet clock-in time)
    @timesheets = @timesheets.where(clock_in_at: @week_start..@week_end)

    @timesheets = @timesheets.includes(shift: [ :location, :user ]).order(clock_in_at: :desc)

    if @selected_location_id.present?
      @timesheets = @timesheets.joins(shift: :location).where(locations: { id: @selected_location_id })
    end
  end
end
