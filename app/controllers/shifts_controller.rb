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
  def edit
    render partial: "form_modal", locals: { shift: @shift }
  end

  # POST /shifts (Handles form submission from the modal)
  def create
    shift_date = Date.parse(shift_params[:date].to_s)
    @shift = Shift.new(shift_params.except(:date))
    @shift.start_time = @shift.start_time.change(year: shift_date.year, month: shift_date.month, day: shift_date.day)
    @shift.end_time = @shift.end_time.change(year: shift_date.year, month: shift_date.month, day: shift_date.day)

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

  # PATCH/PUT /shifts/1 (Handles both drag-and-drop and modal form updates)
  def update
    @roster = @shift.roster
    @old_user = @shift.user
    @old_date = @shift.start_time.to_date

    is_drag_and_drop = shift_params[:start_time].blank?

    if is_drag_and_drop
      new_date = Date.parse(shift_params[:date].to_s)
      attrs_to_update = {
        user_id: shift_params[:user_id],
        start_time: @shift.start_time.change(year: new_date.year, month: new_date.month, day: new_date.day),
        end_time: @shift.end_time.change(year: new_date.year, month: new_date.month, day: new_date.day)
      }
    else
      attrs_to_update = shift_params.except(:date)
      if shift_params[:date].present?
        new_date = Date.parse(shift_params[:date].to_s)
        start_time_from_params = Time.zone.parse(shift_params[:start_time])
        end_time_from_params = Time.zone.parse(shift_params[:end_time])
        attrs_to_update[:start_time] = start_time_from_params.change(year: new_date.year, month: new_date.month, day: new_date.day)
        attrs_to_update[:end_time] = end_time_from_params.change(year: new_date.year, month: new_date.month, day: new_date.day)
      end
    end

    if @shift.update(attrs_to_update)
      respond_to do |format|
        # Rails will now automatically find and render update.turbo_stream.erb
        # The view will use the instance variables @shift, @roster, @old_user, and @old_date.
        format.turbo_stream
        format.html { redirect_to roster_path(@roster), notice: "Shift updated." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render partial: "form_modal", status: :unprocessable_entity, locals: { shift: @shift } }
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /shifts/1
 def destroy
  # Store the user and roster before destroying the shift, so we can
  # use them in the turbo stream view to update the UI correctly.
  @user = @shift.user
  @roster = @shift.roster
  
  @shift.destroy!

  respond_to do |format|
    # This line tells Rails to look for destroy.turbo_stream.erb
    format.turbo_stream
    format.html { redirect_to roster_path(@roster), status: :see_other, notice: "Shift deleted." }
    format.json { head :no_content }
  end
end

  private

  def set_shift
    @shift = Shift.find(params[:id])
  end

  def shift_params
    params.require(:shift).permit(:user_id, :location_id, :roster_id, :start_time, :end_time, :date, :recurrence_id, :area_id)
  end
end