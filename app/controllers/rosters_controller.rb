class RostersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_roster, only: %i[show edit update destroy publish copy_previous_week revert_to_draft]

  # GET /rosters
  def index
    starts_on = Date.today.beginning_of_week
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
    @date = params[:date] ? Date.parse(params[:date]) : Date.today
    @show_all_days = params[:show_all_days] == "true"
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

  def revert_to_draft
    @roster.update(status: Roster::STATUSES[:draft])
    redirect_to @roster, notice: "Roster has been reverted to draft."
  end

  def show_by_date
    starts_on = params[:date] ? Date.parse(params[:date]) : Date.today.beginning_of_week
    roster = Roster.find_or_initialize_by(starts_on: starts_on)
    if roster.new_record?
      roster.status = Roster::STATUSES[:draft]
      roster.save!
    end
    redirect_to roster_path(roster, location_id: params[:location_id], date: params[:date])
  end

  # POST /rosters/:id/copy_previous_week
  def copy_previous_week
    previous_roster = Roster.where(starts_on: @roster.starts_on - 7).first

    if previous_roster.present?
      previous_roster.shifts.each do |shift|
        @roster.shifts.create!(
          user_id: shift.user_id,
          location_id: shift.location_id,
          area_id: shift.area_id,
          start_time: shift.start_time + 7.days,
          end_time: shift.end_time + 7.days
        )
      end
      redirect_to @roster, notice: "Previous week's shifts copied."
    else
      redirect_to @roster, alert: "No previous roster found."
    end
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
