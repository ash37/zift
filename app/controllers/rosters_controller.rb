class RostersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_roster, only: %i[show edit update destroy publish copy_previous_week revert_to_draft publish_with_email]

  # GET /rosters
  def index
    starts_on = Date.today.beginning_of_week(:wednesday)
    roster = Roster.find_or_initialize_by(starts_on: starts_on)
    if roster.new_record?
      roster.status = Roster::STATUSES[:draft]
      roster.save!
    end
    redirect_to roster_path(roster)
  end

  # GET /rosters/1
  def show
    @locations = Location.all
    @selected_location_id = params[:location_id]
    @current_location = Location.find_by(id: @selected_location_id)
    @date = params[:date] ? Date.parse(params[:date]) : Date.today
    @show_all_days = params[:show_all_days] == "true"

    # Eager load associations to avoid N+1s in views
    @roster.shifts.includes(:user, :location, :area).load

    # Work on an in-memory collection, optionally filtered by selected location
    shifts = @roster.shifts
    shifts = shifts.select { |s| s.location_id.to_s == @selected_location_id.to_s } if @selected_location_id.present?

    # Index shifts by [user_id, date] for fast per-cell lookups in _cell_content
    @shifts_by_user_and_date = shifts.group_by { |s| [ s.user_id, s.start_time.to_date ] }

    # Precompute daily totals for _daily_hours
    @hours_by_date = shifts
      .group_by { |s| s.start_time.to_date }
      .transform_values { |ss| ss.sum { |s| (s.end_time - s.start_time) / 3600.0 } }

    # Preload approved unavailability for the roster week for all relevant users
    week_start = @roster.starts_on
    week_range = week_start.beginning_of_day..(week_start + 6.days).end_of_day
    user_ids = shifts.map(&:user_id).uniq

    @unavailability_by_user = if user_ids.empty?
      {}
    else
      UnavailabilityRequest
        .where(user_id: user_ids, status: UnavailabilityRequest::STATUSES[:approved])
        .where("starts_at <= ? AND ends_at >= ?", week_range.end, week_range.begin)
        .group_by(&:user_id)
    end

    # Provide the users collection for roster tables (desktop + mobile)
    @users_for_roster = if @selected_location_id.present?
      User.where.not(role: nil)
          .joins(:shifts)
          .where(shifts: { roster_id: @roster.id, location_id: @selected_location_id })
          .distinct
    else
      User.where.not(role: nil)
          .joins(:shifts)
          .where(shifts: { roster_id: @roster.id })
          .distinct
    end
  end

  # GET /rosters/new
  def new
    @roster = Roster.new
  end

  # GET /rosters/1/edit
  def edit; end

  # POST /rosters
  def create
    @roster = Roster.new(roster_params)

    respond_to do |format|
      if @roster.save
        format.html { redirect_to @roster, notice: "Roster was successfully created." }
        format.json { render :show, status: :created, location: @roster }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @roster.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /rosters/1
  def update
    respond_to do |format|
      if @roster.update(roster_params)
        format.html { redirect_to @roster, notice: "Roster was successfully updated." }
        format.json { render :show, status: :ok, location: @roster }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @roster.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /rosters/1
  def destroy
    @roster.destroy!
    respond_to do |format|
      format.html { redirect_to rosters_path, status: :see_other, notice: "Roster was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  # POST /rosters/:id/publish
  def publish
    if @roster.shifts.empty?
      redirect_to @roster, alert: "There are unassigned shifts in this roster. Are you sure you want to publish?"
      return
    end

    @roster.update(status: Roster::STATUSES[:published])
    redirect_to @roster, notice: "Roster published."
  end

  def publish_with_email
    @roster.update(status: Roster::STATUSES[:published])
    @roster.shifts.map(&:user).uniq.each do |user|
      RosterMailer.with(user: user, roster: @roster).roster_published.deliver_now
    end
    @roster.update(emails_sent_at: Time.current)
    redirect_to @roster, notice: "Roster published and emails sent."
  end

  def revert_to_draft
    @roster.update(status: Roster::STATUSES[:draft])
    redirect_to @roster, notice: "Roster has been reverted to draft."
  end

  def show_by_date
    current_date = params[:date] ? Date.parse(params[:date]) : Date.today
    starts_on = current_date.beginning_of_week(:wednesday)

    roster = Roster.find_or_initialize_by(starts_on: starts_on)
    if roster.new_record?
      roster.status = Roster::STATUSES[:draft]
      roster.save!
    end
    redirect_to roster_path(roster, location_id: params[:location_id], date: current_date)
  end

  # POST /rosters/:id/copy_previous_week
  def copy_previous_week
    previous_roster = Roster.find_by(starts_on: @roster.starts_on - 7.days)
    return redirect_to(@roster, alert: "No previous roster found.") unless previous_roster

    only_location_id = params[:location_id].presence
    copied = 0

    ActiveRecord::Base.transaction do
      scope = previous_roster.shifts.includes(:area, :user, :location)
      scope = scope.where(location_id: only_location_id) if only_location_id

      scope.find_each do |s|
        dup = s.dup
        dup.roster_id = @roster.id
        dup.start_time = s.start_time + 7.days
        dup.end_time   = s.end_time + 7.days
        dup.note       = s.note
        dup.area_id    = s.area_id
        dup.location_id = s.location_id

        Rails.logger.info("[CopyWeek] Preparing to copy src=#{s.id} -> dup(user=#{dup.user_id} loc=#{dup.location_id} area=#{dup.area_id.inspect} note=#{dup.note.inspect} start=#{dup.start_time} end=#{dup.end_time})")

        if dup.area_id && dup.area && dup.area.location_id != dup.location_id
          Rails.logger.warn("[CopyWeek] Area #{dup.area_id} not in location #{dup.location_id}; clearing area_id")
          dup.area_id = nil
        end

        Rails.logger.info("[CopyWeek] src=#{s.id} -> new user=#{dup.user_id} loc=#{dup.location_id} area=#{dup.area_id.inspect} note=#{dup.note.inspect}")

        dup.save!
        copied += 1
      end
    end

    redirect_to roster_path(@roster, location_id: only_location_id), notice: "#{copied} shift#{'s' if copied != 1} copied from last week."
  end

  private

  def set_roster
    @roster = Roster.find_by(id: params[:id])
    redirect_to rosters_path, alert: "Roster not found." unless @roster
  end

  def roster_params
    params.require(:roster).permit(:starts_on, :status)
  end
end
