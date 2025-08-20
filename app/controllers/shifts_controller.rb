# app/controllers/shifts_controller.rb
class ShiftsController < ApplicationController
  before_action :authenticate_user!
  include ActionView::RecordIdentifier
  before_action :set_shift, only: %i[show edit update destroy clock_on]

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
      @new_user = @shift.user
      @new_date = @shift.start_time.to_date

      streams = []

      # Always update the destination cell
      streams << turbo_stream.replace(
        dom_id(@roster, "cell_content_#{@new_user.id}_#{@new_date}"),
        partial: "rosters/cell_content",
        locals: { roster: @roster, user: @new_user, date: @new_date, selected_location_id: @selected_location_id }
      )

      # Update the source cell if it changed (user and/or date)
      if @old_user.id != @new_user.id || @old_date != @new_date
        streams << turbo_stream.replace(
          dom_id(@roster, "cell_content_#{@old_user.id}_#{@old_date}"),
          partial: "rosters/cell_content",
          locals: { roster: @roster, user: @old_user, date: @old_date, selected_location_id: @selected_location_id }
        )
      end

      # Update per-user hours for new and (if different) old user
      streams << turbo_stream.replace(
        dom_id(@roster, "user_hours_#{@new_user.id}"),
        partial: "rosters/user_hours",
        locals: { roster: @roster, user: @new_user, selected_location_id: @selected_location_id }
      )
      if @old_user.id != @new_user.id
        streams << turbo_stream.replace(
          dom_id(@roster, "user_hours_#{@old_user.id}"),
          partial: "rosters/user_hours",
          locals: { roster: @roster, user: @old_user, selected_location_id: @selected_location_id }
        )
      end

      # Update per-day totals for new and (if different) old date
      streams << turbo_stream.replace(
        dom_id(@roster, "daily_hours_#{@new_date}"),
        partial: "rosters/daily_hours",
        locals: { roster: @roster, date: @new_date, selected_location_id: @selected_location_id }
      )
      if @old_date != @new_date
        streams << turbo_stream.replace(
          dom_id(@roster, "daily_hours_#{@old_date}"),
          partial: "rosters/daily_hours",
          locals: { roster: @roster, date: @old_date, selected_location_id: @selected_location_id }
        )
      end

      # If the update came from the modal, close it on success
      unless is_drag_and_drop
        streams << turbo_stream.replace("assign_shift_modal", "")
      end

      respond_to do |format|
        format.turbo_stream { render turbo_stream: streams }
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

  # POST /shifts/:id/clock_on
  def clock_on
    # Create or find an open timesheet for this shift
    @timesheet = @shift.timesheets.where(user: current_user, clock_out_at: nil).first_or_initialize
    if @timesheet.new_record?
      @timesheet.user = current_user
      @timesheet.area = @shift.area if @timesheet.respond_to?(:area=)
      @timesheet.clock_in_at = Time.current
    end

    # Build any provided pre-shift answers
    answers_attrs = params.dig(:timesheet, :shift_answers_attributes)
    if answers_attrs.present?
      answers_attrs.each_value do |qa|
        next if qa[:answer_text].blank?
        @timesheet.shift_answers.build(
          answer_text: qa[:answer_text],
          shift_id: @shift.id,
          timesheet_id: @timesheet.id, # set after save too, but safe here
          shift_question_id: qa[:shift_question_id],
          user_id: current_user.id
        )
      end
    end

    # Validate mandatory pre-shift questions are answered when present
    mandatory_ids = @shift.pre_shift_questions.where(is_mandatory: true).pluck(:id)
    if mandatory_ids.any?
      provided_ids = Array(answers_attrs).map { |_, v| v[:shift_question_id].to_i if v[:answer_text].present? }.compact
      missing_ids = mandatory_ids - provided_ids
      if missing_ids.any?
        flash[:alert] = "Please answer all mandatory pre-shift questions."
        return redirect_back(fallback_location: shifts_path)
      end
    end

    if @timesheet.save
      # Ensure answers have the timesheet id persisted
      if @timesheet.shift_answers.any?
        @timesheet.shift_answers.each { |a| a.timesheet_id ||= @timesheet.id }
        @timesheet.shift_answers.each(&:save!)
      end
      flash[:notice] = "Clocked on. Have a great shift!"
      redirect_back(fallback_location: shifts_path)
    else
      flash[:alert] = @timesheet.errors.full_messages.to_sentence
      redirect_back(fallback_location: shifts_path)
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
