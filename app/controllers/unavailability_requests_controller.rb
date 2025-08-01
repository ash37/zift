class UnavailabilityRequestsController < ApplicationController
  before_action :set_unavailability_request, only: %i[ show edit update destroy ]

  # GET /unavailability_requests or /unavailability_requests.json
  def index
    @unavailability_requests = UnavailabilityRequest.all
  end

  # GET /unavailability_requests/1 or /unavailability_requests/1.json
  def show
  end

  # GET /unavailability_requests/new
  def new
    @unavailability_request = UnavailabilityRequest.new
  end

  # GET /unavailability_requests/1/edit
  def edit
  end

  # POST /unavailability_requests or /unavailability_requests.json
  def create
    @unavailability_request = UnavailabilityRequest.new(unavailability_request_params)

    respond_to do |format|
      if @unavailability_request.save
        format.html { redirect_to @unavailability_request, notice: "Unavailability request was successfully created." }
        format.json { render :show, status: :created, location: @unavailability_request }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @unavailability_request.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /unavailability_requests/1 or /unavailability_requests/1.json
  def update
    respond_to do |format|
      if @unavailability_request.update(unavailability_request_params)
        format.html { redirect_to @unavailability_request, notice: "Unavailability request was successfully updated." }
        format.json { render :show, status: :ok, location: @unavailability_request }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @unavailability_request.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /unavailability_requests/1 or /unavailability_requests/1.json
  def destroy
    @unavailability_request.destroy!

    respond_to do |format|
      format.html { redirect_to unavailability_requests_path, status: :see_other, notice: "Unavailability request was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_unavailability_request
      @unavailability_request = UnavailabilityRequest.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def unavailability_request_params
      params.expect(unavailability_request: [ :user_id, :starts_at, :ends_at, :reason, :status ])
    end
end
