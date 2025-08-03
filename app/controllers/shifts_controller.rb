# app/controllers/shifts_controller.rb
class ShiftsController < ApplicationController
  before_action :set_shift, only: %i[show edit update destroy]

  # GET /shifts
  def index
    @shifts = Shift.all
  end

  # GET /shifts/1
  def show; end

  # GET /shifts/new (for turbo modal)
  # This action prepares a new shift object for the modal form.
  def new
    @shift = Shift.new(
      user_id: params[:user_id],
      roster_id: params[:roster_id],
      # We set a default start and end time based on the date from the params.
      start_time: params[:date].to_date.beginning_of_day + 9.hours,
      end_time: params[:date].to_date.beginning_of_day + 17.hours
    )
    # Renders the modal form without a full page reload.
    render partial: "form_modal", locals: { shift: @shift }
  end

  # GET /shifts/1/edit
  def edit; end

  # POST /shifts (Handles form submission from the modal)
  def create
    # Extract the date from the permitted parameters.
    shift_date = Date.parse(shift_params[:date].to_s)

    # Create a new shift instance, but exclude the :date attribute to prevent an error,
    # as the Shift model does not have a 'date' column in the database.
    @shift = Shift.new(shift_params.except(:date))

    # Manually combine the selected date with the start and end times from the form.
    @shift.start_time = @shift.start_time.change(year: shift_date.year, month: shift_date.month, day: shift_date.day)
    @shift.end_time = @shift.end_time.change(year: shift_date.year, month: shift_date.month, day: shift_date.day)

    respond_to do |format|
      if @shift.save
        # If successful, respond with a Turbo Stream to update the roster.
        format.turbo_stream
        format.html { redirect_to roster_path(@shift.roster_id), notice: "Shift created." }
      else
        # If there are validation errors, re-render the form with the errors.
        format.turbo_stream { render partial: "form_modal", status: :unprocessable_entity, locals: { shift: @shift } }
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /shifts/1 (Handles drag-and-drop updates)
  def update
    # Store the shift's original user and date to correctly update the source cell.
    @old_user = @shift.user
    @old_date = @shift.start_time.to_date
    @roster = @shift.roster

    # Parse the new date from the parameters sent by the drag controller.
    new_date = Date.parse(shift_params[:date].to_s)
    
    # Build a hash of the attributes we want to update.
    update_attrs = {
      user_id: shift_params[:user_id],
      start_time: @shift.start_time.change(year: new_date.year, month: new_date.month, day: new_date.day),
      end_time: @shift.end_time.change(year: new_date.year, month: new_date.month, day: new_date.day)
    }

    if @shift.update(update_attrs)
      # If the update is successful, respond with a Turbo Stream.
      respond_to do |format|
        format.turbo_stream { render locals: { old_user: @old_user, old_date: @old_date } }
      end
    else
      # If saving fails, redirect back with an alert.
      redirect_to roster_path(@roster), alert: "Could not move shift."
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

  # Use callbacks to share common setup or constraints between actions.
  def set_shift
    @shift = Shift.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def shift_params
    params.require(:shift).permit(:user_id, :location_id, :roster_id, :start_time, :end_time, :date, :recurrence_id)
  end
end
