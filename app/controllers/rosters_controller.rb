class RostersController < ApplicationController
  before_action :set_roster, only: [ :show, :copy_previous_week, :revert_to_draft ]

  # GET /rosters
  def index
    @rosters = Roster.order(starts_on: :desc)
  end

  # GET /rosters/:id
  def show
    # @roster, @date, and @selected_location_id are set in set_roster
  end

  # GET /rosters/week/:date
  # Creates the roster for the date if it does not exist, then redirects to show
  def show_by_date
    date_param = params[:date].to_s
    begin
      date = Date.parse(date_param)
    rescue ArgumentError
      return redirect_to(rosters_path, alert: "Invalid date provided.")
    end

    roster = Roster.find_by(starts_on: date)
    unless roster
      roster = Roster.create!(starts_on: date, status: 0)
    end

    redirect_to roster_path(roster, date: date, location_id: params[:location_id])
  end
  # POST /rosters/:id/copy_previous_week
  def copy_previous_week
    weeks_ago = params[:weeks_ago].to_i
    weeks_ago = 1 if weeks_ago <= 0
    weeks_ago = 4 if weeks_ago > 4

    previous_roster = Roster.find_by(starts_on: @roster.starts_on - weeks_ago.weeks)
    return redirect_to(@roster, alert: "No roster found from #{weeks_ago} week#{'s' if weeks_ago > 1} ago.") unless previous_roster

    only_location_id = params[:location_id].presence
    copied = 0

    ActiveRecord::Base.transaction do
      scope = previous_roster.shifts.includes(:area, :user, :location)
      scope = scope.where(location_id: only_location_id) if only_location_id

      scope.find_each do |s|
        dup = s.dup
        dup.roster_id   = @roster.id
        dup.start_time  = s.start_time + weeks_ago.weeks
        dup.end_time    = s.end_time   + weeks_ago.weeks
        dup.note        = s.note
        dup.area_id     = s.area_id
        dup.location_id = s.location_id

        Rails.logger.info("[CopyWeek w=#{weeks_ago}] Preparing to copy src=#{s.id} -> dup(user=#{dup.user_id} loc=#{dup.location_id} area=#{dup.area_id.inspect} note=#{dup.note.inspect} start=#{dup.start_time} end=#{dup.end_time})")

        if dup.area_id && dup.area && dup.area.location_id != dup.location_id
          Rails.logger.warn("[CopyWeek w=#{weeks_ago}] Area #{dup.area_id} not in location #{dup.location_id}; clearing area_id")
          dup.area_id = nil
        end

        Rails.logger.info("[CopyWeek w=#{weeks_ago}] src=#{s.id} -> new user=#{dup.user_id} loc=#{dup.location_id} area=#{dup.area_id.inspect} note=#{dup.note.inspect}")

        dup.save!
        copied += 1
      end
    end

    msg = "#{copied} shift#{'s' if copied != 1} copied from #{weeks_ago} week#{'s' if weeks_ago > 1} ago."
    redirect_to roster_path(@roster, location_id: only_location_id), notice: msg
  end

  # POST /rosters/:id/revert_to_draft
  def revert_to_draft
    # @roster is set by set_roster
    unless @roster
      redirect_to rosters_path, alert: "Roster not found." and return
    end
    @roster.update!(status: Roster::STATUSES[:draft])
    redirect_to roster_path(@roster), notice: "Roster reverted to draft."
  end

  private

  def set_roster
    # Prefer id when present (normal /rosters/:id routes)
    @roster = Roster.find_by(id: params[:id])

    # Fallback: if coming from /rosters/week?date=... or similar
    if @roster.nil? && params[:date].present?
      begin
        parsed_date = Date.parse(params[:date].to_s)
        @roster = Roster.find_by(starts_on: parsed_date)
      rescue ArgumentError
        # Invalid date provided; leave @roster nil so we fall through to redirect
      end
    end

    # Prepare commonly used view vars
    @date = if params[:date].present?
      begin
        Date.parse(params[:date].to_s)
      rescue ArgumentError
        nil
      end
    else
      @roster&.starts_on
    end

    @selected_location_id = params[:location_id].presence&.to_i

    # If still nil, bail out gracefully to avoid nil errors in views
    unless @roster
      redirect_to rosters_path, alert: "Roster not found."
    end
  end
end
