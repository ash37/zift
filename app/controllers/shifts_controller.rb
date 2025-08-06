# app/controllers/shifts_controller.rb
class ShiftsController < ApplicationController
  include ActionView::RecordIdentifier
  before_action :set_shift, only: %i[show edit update destroy]

  # GET /shifts
  def index
    @shifts = Shift.all
  end

  # GET /shifts/1
  def show; end

  # GET /shifts/new (for turbo modal)
  def new
    @selected_location_id = params[:location_id]
    @shift = Shift.new(
      user_id: params[:user_id],
      roster_id: params[:roster_id],
      location_id: params[:location_id],
      start_time: params[:date].to_date.beginning_of_day + 9.hours,
      end_time: params[:date].to_date.beginning_of_day + 17.hours
    )
    render partial: "shifts/form_modal", locals: { shift: @shift }
  end

  # GET /shifts/1/edit
  def edit
    @selected_location_id = params[:location_id]
    render partial: "shifts/form_modal", locals: { shift: @shift }
  end

  # POST /shifts (Handles form submission from the modal)
  def create
    @selected_location_id = shift_params[:roster_filter_location_id]
    shift_date = Date.parse(shift_params[:date].to_s)
    @shift = Shift.new(shift_params.except(:date, :roster_filter_location_id))
    @shift.start_time = @shift.start_time.change(year: shift_date.year, month: shift_date.month, day: shift_date.day)
    @shift.end_time = @shift.end_time.change(year: shift_date.year, month: shift_date.month, day: shift_date.day)

    respond_to do |format|
      if @shift.save
        format.turbo_stream
        format.html { redirect_to roster_path(@shift.roster_id), notice: "Shift created." }
      else
        format.turbo_stream do
          flash.now[:alert] = @shift.errors.full_messages.to_sentence
          render turbo_stream: [
            turbo_stream.replace("assign_shift_modal",
              partial: "shifts/form_modal",
              locals: { shift: @shift }),
            turbo_stream.replace("flash",
              partial: "layouts/flash")
          ], status: :unprocessable_entity
        end
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /shifts/1 (Handles both drag-and-drop and modal form updates)
  def update
    @selected_location_id = shift_params[:roster_filter_location_id]
    @roster = @shift.roster
    @old_user = @shift.user
    @old_date = @shift.start_time.to_date

    is_drag_and_drop = shift_params[:start_time].blank?

    attrs_to_update = shift_params.except(:date, :roster_filter_location_id)

    if is_drag_and_drop
      new_date = Date.parse(shift_params[:date].to_s)
      attrs_to_update.merge!(
        start_time: @shift.start_time.change(year: new_date.year, month: new_date.month, day: new_date.day),
        end_time: @shift.end_time.change(year: new_date.year, month: new_date.month, day: new_date.day)
      )
    elsif shift_params[:date].present?
      new_date = Date.parse(shift_params[:date].to_s)
      start_time_from_params = Time.zone.parse(shift_params[:start_time])
      end_time_from_params = Time.zone.parse(shift_params[:end_time])
      attrs_to_update.merge!(
        start_time: start_time_from_params.change(year: new_date.year, month: new_date.month, day: new_date.day),
        end_time: end_time_from_params.change(year: new_date.year, month: new_date.month, day: new_date.day)
      )
    end

    if @shift.update(attrs_to_update)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to roster_path(@roster), notice: "Shift updated." }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = @shift.errors.full_messages.to_sentence
          if is_drag_and_drop
            # Drag-and-drop failed validation: Revert the shift and show a flash message.
            render turbo_stream: [
              turbo_stream.replace("flash", partial: "layouts/flash"),
              turbo_stream.replace(dom_id(@roster, "cell_content_#{@old_user.id}_#{@old_date}"),
                partial: "rosters/cell_content",
                locals: { roster: @roster, user: @old_user, date: @old_date, selected_location_id: @selected_location_id })
            ], status: :unprocessable_entity
          else
            # Modal form submission failed validation: Re-render the modal with errors.
            render turbo_stream: [
              turbo_stream.replace("assign_shift_modal",
                partial: "shifts/form_modal",
                locals: { shift: @shift }),
              turbo_stream.replace("flash",
                partial: "layouts/flash")
            ], status: :unprocessable_entity
          end
        end
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /shifts/1
  def destroy
    @selected_location_id = params[:roster_filter_location_id]
    @user = @shift.user
    @roster = @shift.roster

    @shift.destroy!

    respond_to do |format|
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
    params.require(:shift).permit(:user_id, :location_id, :roster_id, :start_time, :end_time, :date, :recurrence_id, :area_id, :roster_filter_location_id, :note)
  end
end
