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
    params.require(:shift).permit(:user_id, :location_id, :roster_id, :start_time, :end_time, :recurrence_id)
  end
end
