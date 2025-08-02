class ShiftsController < ApplicationController
  before_action :set_shift, only: %i[show edit update destroy]

  # GET /shifts
  def index
    @shifts = Shift.all
  end

  # GET /shifts/1
  def show; end

  # GET /shifts/new (for turbo modal)
  def new
    @shift = Shift.new(
      user_id: params[:user_id],
      roster_id: params[:roster_id],
      start_time: params[:date].to_date.beginning_of_day + 9.hours,
      end_time: params[:date].to_date.beginning_of_day + 17.hours
    )
    render partial: "form_modal", locals: { shift: @shift }
  end

  # GET /shifts/1/edit
  def edit; end

  # POST /shifts (Turbo or full HTML)
  def create
    @shift = Shift.new(shift_params)

    respond_to do |format|
      if @shift.save
        format.turbo_stream
        format.html { redirect_to roster_path(@shift.roster_id), notice: "Shift created." }
      else
        format.turbo_stream { render partial: "form_modal", status: :unprocessable_entity, locals: { shift: @shift } }
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /shifts/1
  def update
    respond_to do |format|
      if @shift.update(shift_params)
        format.html { redirect_to shift_path(@shift), notice: "Shift updated." }
        format.json { render :show, status: :ok, location: @shift }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @shift.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /shifts/1
  def destroy
    @shift.destroy!
    respond_to do |format|
      format.html { redirect_to shifts_path, status: :see_other, notice: "Shift deleted." }
      format.json { head :no_content }
    end
  end

  private

  def set_shift
    @shift = Shift.find(params[:id])
  end

  def shift_params
    params.require(:shift).permit(:user_id, :location_id, :roster_id, :start_time, :end_time, :recurrence_id)
  end
end
