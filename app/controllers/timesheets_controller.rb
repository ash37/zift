class TimesheetsController < ApplicationController
  before_action :set_timesheet, only: %i[ show edit update destroy ]

  # GET /timesheets or /timesheets.json
  def index
    @timesheets = Timesheet.all
  end

  # GET /timesheets/1 or /timesheets/1.json
  def show
  end

  # GET /timesheets/new
  def new
    @timesheet = Timesheet.new
  end

  # GET /timesheets/1/edit
  def edit
  end

  # POST /timesheets or /timesheets.json
  def create
    @timesheet = Timesheet.new(timesheet_params)

    respond_to do |format|
      if @timesheet.save
        format.html { redirect_to @timesheet, notice: "Timesheet was successfully created." }
        format.json { render :show, status: :created, location: @timesheet }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @timesheet.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /timesheets/1 or /timesheets/1.json
  def update
    respond_to do |format|
      if @timesheet.update(timesheet_params)
        format.html { redirect_to @timesheet, notice: "Timesheet was successfully updated." }
        format.json { render :show, status: :ok, location: @timesheet }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @timesheet.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /timesheets/1 or /timesheets/1.json
  def destroy
    @timesheet.destroy!

    respond_to do |format|
      format.html { redirect_to timesheets_path, status: :see_other, notice: "Timesheet was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_timesheet
      @timesheet = Timesheet.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def timesheet_params
      params.expect(timesheet: [ :user_id, :shift_id, :clock_in_at, :clock_out_at, :duration, :status ])
    end
end
