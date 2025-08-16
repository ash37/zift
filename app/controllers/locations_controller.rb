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
      params.require(:location).permit(:name, :address, :phone_number, areas_attributes: [ :id, :name, :_destroy ])
    end
end
