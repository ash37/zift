class TimesheetsController < ApplicationController
  before_action :set_timesheet, only: %i[ show edit update destroy approve clock_off_form clock_off ]

  # GET /timesheets
  def index
    base_scope = Shift.joins(:roster)
                      .where(rosters: { status: Roster::STATUSES[:published] })
                      .order("shifts.start_time ASC")

    if current_user.admin? || current_user.manager?
      @shifts = base_scope.all
    else
      @shifts = base_scope.where(user_id: current_user.id)
    end
  end

  # GET /timesheets/1
  def show
  end

  # GET /timesheets/new
  def new
    @timesheet = Timesheet.new
  end

  # GET /timesheets/1/edit
  def edit
  end

  # POST /timesheets
  def create
    @timesheet = Timesheet.new(timesheet_params)

    if @timesheet.save
      redirect_to @timesheet, notice: "Timesheet was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /timesheets/1
  def update
    # The form is now an "Approve" form, so we merge the approved status.
    updated_params = timesheet_params.merge(status: Timesheet::STATUSES[:approved])

    shift_date = @timesheet.shift.start_time.to_date

    if params[:timesheet][:clock_in_at].present?
      clock_in_time = Time.zone.parse(params[:timesheet][:clock_in_at])
      updated_params[:clock_in_at] = clock_in_time.change(year: shift_date.year, month: shift_date.month, day: shift_date.day)
    end

    if params[:timesheet][:clock_out_at].present?
      clock_out_time = Time.zone.parse(params[:timesheet][:clock_out_at])
      updated_params[:clock_out_at] = clock_out_time.change(year: shift_date.year, month: shift_date.month, day: shift_date.day)
    end

    if @timesheet.update(updated_params)
      redirect_to timesheets_path, notice: "Timesheet was successfully updated and approved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /timesheets/1
  def destroy
    @timesheet.destroy!
    redirect_to timesheets_url, notice: "Timesheet was successfully destroyed.", status: :see_other
  end

  def clock_on
    @shift = Shift.find(params[:id])
    if @shift.timesheets.where(user: current_user, clock_out_at: nil).none?
      @timesheet = @shift.timesheets.create(
        user: current_user,
        clock_in_at: Time.current,
        status: Timesheet::STATUSES[:pending]
      )
      redirect_to dashboards_path, notice: "Clocked on successfully."
    else
      redirect_to dashboards_path, alert: "You are already clocked on for this shift."
    end
  end

  def clock_off_form
    # Renders the view
  end

  def clock_off
    if @timesheet.update(clock_off_params.merge(clock_out_at: Time.current))
      redirect_to dashboards_path, notice: "Clocked off successfully."
    else
      render :clock_off_form, status: :unprocessable_entity
    end
  end

  def approve
    if @timesheet.update(status: Timesheet::STATUSES[:approved])
      redirect_to timesheets_path, notice: "Timesheet approved."
    else
      redirect_to timesheets_path, alert: "Could not approve timesheet."
    end
  end

  private
    def set_timesheet
      @timesheet = Timesheet.find(params[:id])
    end

    def timesheet_params
      params.require(:timesheet).permit(:clock_in_at, :clock_out_at, :notes, :travel, shift_attributes: [ :id, :area_id ])
    end

    def clock_off_params
      params.require(:timesheet).permit(:notes, :travel)
    end
end
