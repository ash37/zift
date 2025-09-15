class RostersController < ApplicationController
  include ActionView::RecordIdentifier
  before_action :set_roster, only: [ :show, :compact, :day_details, :day_pills, :copy_previous_week, :revert_to_draft, :publish, :publish_with_email ]

  # GET /rosters
  def index
    @rosters = Roster.order(starts_on: :desc)
  end

  # GET /rosters/:id
  def show
    # @roster, @date, and @selected_location_id are set in set_roster
  end

  # GET /rosters/:id/compact
  # Compact roster view with denser layout and drag-and-drop
  def compact
    # Loads same instance vars as show via set_roster
    # Optionally set current location for sub-nav label
    @current_location = Location.find_by(id: @selected_location_id) if @selected_location_id.present?
  end

  # GET /rosters/week/:date
  # Creates the roster for the date if it does not exist, then redirects to show
  def show_by_date
    date_param = params[:date].to_s
    begin
      parsed = Date.parse(date_param)
    rescue ArgumentError
      return redirect_to(rosters_path, alert: "Invalid date provided.")
    end

    # Normalize to the Wednesday of that week to ensure a single canonical period (Wed–Tue)
    week_start = parsed.beginning_of_week(:wednesday)

    roster = Roster.find_by(starts_on: week_start)
    unless roster
      roster = Roster.create!(starts_on: week_start, status: Roster::STATUSES[:draft])
    end

    redirect_to roster_path(roster, date: week_start, location_id: params[:location_id])
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

  # POST /rosters/:id/publish
  def publish
    # @roster is set by set_roster
    unless @roster
      redirect_to rosters_path, alert: "Roster not found." and return
    end

    @roster.update!(status: Roster::STATUSES[:published])
    redirect_to roster_path(@roster), notice: "Roster published."
  end

  # POST /rosters/:id/publish_with_email
  def publish_with_email
    # @roster is set by set_roster
    unless @roster
      redirect_to rosters_path, alert: "Roster not found." and return
    end

    @roster.update!(status: Roster::STATUSES[:published])

    # Send emails to all users who have shifts in this roster
    users_to_notify = User.joins(:shifts).where(shifts: { roster_id: @roster.id }).distinct
    users_to_notify.find_each do |u|
      RosterMailer.with(user: u, roster: @roster).roster_published.deliver_later
    end

    redirect_to roster_path(@roster), notice: "Roster published and notifications sent."
  end

  # GET /rosters/:id/day_details
  # Returns all shifts for a user on a date within the roster; renders into assign_shift_modal
  def day_details
    user = User.find(params[:user_id])
    date = Date.parse(params[:date].to_s)

    scope = @roster.shifts.where(user: user, start_time: date.all_day)
    scope = scope.where(location_id: @selected_location_id) if @selected_location_id.present?
    @shifts_for_day = scope.includes(:area, :location).to_a
    @day            = date
    @user           = user

    render partial: "rosters/day_details_modal"
  end

  # GET /rosters/:id/day_pills
  # Returns compact draggable list of shifts for user/date; used to refresh a cell via Turbo Streams
  def day_pills
    user = User.find(params[:user_id])
    date = Date.parse(params[:date].to_s)

    @user = user
    @day  = date

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          dom_id(@roster, "cell_content_#{user.id}_#{date}"),
          partial: "rosters/compact_cell_content",
          locals: { roster: @roster, user: user, date: date, selected_location_id: @selected_location_id, compact: true }
        )
      end
      format.html do
        render partial: "rosters/compact_cell_content", locals: { roster: @roster, user: user, date: date, selected_location_id: @selected_location_id, compact: true }
      end
    end
  end

  private

  def set_roster
    # Prefer id when present (normal /rosters/:id routes)
    @roster = Roster.find_by(id: params[:id])

    # Fallback: if coming from /rosters/week?date=... or similar
    if @roster.nil? && params[:date].present?
      begin
        parsed_date = Date.parse(params[:date].to_s)
        week_start = parsed_date.beginning_of_week(:wednesday)
        @roster = Roster.find_by(starts_on: week_start)
      rescue ArgumentError
        # Invalid date provided; leave @roster nil so we fall through to redirect
      end
    end

    # Prepare commonly used view vars
    @date = if params[:date].present?
      begin
        Date.parse(params[:date].to_s).beginning_of_week(:wednesday)
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
