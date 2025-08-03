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
  # Extract the date from the permitted parameters.
  # We use .to_s to ensure it's a string before parsing, preventing errors if it's nil.
  shift_date = Date.parse(shift_params[:date].to_s)

  # Create a new shift instance, but exclude the :date attribute to prevent an error,
  # as the Shift model does not have a 'date' column in the database.
  @shift = Shift.new(shift_params.except(:date))

  # Manually combine the selected date with the start and end times from the form.
  # The .change method updates the date components of the timestamp while preserving the time.
  @shift.start_time = @shift.start_time.change(year: shift_date.year, month: shift_date.month, day: shift_date.day)
  @shift.end_time = @shift.end_time.change(year: shift_date.year, month: shift_date.month, day: shift_date.day)

  respond_to do |format|
    if @shift.save
      # If the shift saves successfully, respond with the appropriate format.
      format.turbo_stream
      format.html { redirect_to roster_path(@shift.roster_id), notice: "Shift created." }
    else
      # If there are validation errors, re-render the form so the user can see them.
      format.turbo_stream { render partial: "form_modal", status: :unprocessable_entity, locals: { shift: @shift } }
      format.html { render :new, status: :unprocessable_entity }
    end
  end
end

  # PATCH/PUT /shifts/1
 def update
    # Parse the new date from the parameters sent by the Stimulus controller.
    new_date = Date.parse(params.dig(:shift, :date))
    
    # Keep the original time but change the date part of start_time and end_time.
    new_start_time = @shift.start_time.change(year: new_date.year, month: new_date.month, day: new_date.day)
    new_end_time = @shift.end_time.change(year: new_date.year, month: new_date.month, day: new_date.day)

    update_params = {
      user_id: params.dig(:shift, :user_id),
      start_time: new_start_time,
      end_time: new_end_time
    }

    if @shift.update(update_params)
      respond_to do |format|
        # Responds with a Turbo Stream to move the shift in the UI.
        format.turbo_stream
        format.html { redirect_to roster_path(@shift.roster) }
      end
    else
      # Handle update failure, perhaps by rendering an error message.
      head :unprocessable_entity
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
    params.require(:shift).permit(:user_id, :location_id, :roster_id, :start_time, :end_time, :date, :recurrence_id)
  end
end
