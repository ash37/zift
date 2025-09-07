class LocationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_location, only: %i[ show edit update destroy archive restore ]

  # GET /locations or /locations.json
  def index
    if params[:archived] == "true"
      @locations = Location.archived
    else
      @locations = Location.all
    end
  end

  # GET /locations/1 or /locations/1.json
  def show
    @area = Area.new(location: @location)
    @areas = @location.areas
  end

  # GET /locations/new
  def new
    @location = Location.new
    @location.areas.build
  end

  # GET /locations/1/edit
  def edit
    @location.areas.build if @location.areas.empty?
  end

  # POST /locations or /locations.json
  def create
    @location = Location.new(location_params)

    respond_to do |format|
      if @location.save
        # This is the updated line. It now redirects to the locations index page.
        format.html { redirect_to locations_url, notice: "Location was successfully created." }
        format.json { render :show, status: :created, location: @location }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @location.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /locations/1 or /locations/1.json
  def update
    respond_to do |format|
      if @location.update(location_params)
        format.html { redirect_to location_url(@location), notice: "Location was successfully updated." }
        format.json { render :show, status: :ok, location: @location }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @location.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /locations/1 or /locations/1.json
  def destroy
    @location.destroy!

    respond_to do |format|
      format.html { redirect_to locations_url, notice: "Location was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def archive
    @location.update(archived_at: Time.current)
    redirect_to locations_url, notice: "Location was successfully archived."
  end

  def restore
    @location.update(archived_at: nil)
    redirect_to locations_url, notice: "Location was successfully restored."
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_location
      # We need to use with_archived here so that we can find archived locations
      @location = Location.with_archived.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def location_params
      # Sanitize nested multi-selects to drop the blank string Rails sends
      if params[:location] && params[:location][:areas_attributes].present?
        params[:location][:areas_attributes].each_value do |attrs|
          attrs[:shift_question_ids]&.reject!(&:blank?)
        end
      end

      params.require(:location).permit(
        :name,
        :address,
        :phone_number,
        :status,
        :representative_name,
        :representative_email,
        :email,
        :phone,
        :date_of_birth,
        :ndis_number,
        :funding,
        :plan_manager_email,
        :interview_info,
        :schedule_info,
        :gender,
        :lives_with,
        :pets,
        :activities_of_interest,
        :tasks,
        areas_attributes: [
          :id,
          :name,
          :export_code,
          :color,
          :xero_item_code,
          :show_timesheet_notes,
          :show_timesheet_travel,
          :_destroy,
          { shift_question_ids: [] }
        ]
      )
    end
end
