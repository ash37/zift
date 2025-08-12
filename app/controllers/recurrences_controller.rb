class RecurrencesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_recurrence, only: %i[ show edit update destroy ]

  # GET /recurrences or /recurrences.json
  def index
    @recurrences = Recurrence.all
  end

  # GET /recurrences/1 or /recurrences/1.json
  def show
  end

  # GET /recurrences/new
  def new
    @recurrence = Recurrence.new
  end

  # GET /recurrences/1/edit
  def edit
  end

  # POST /recurrences or /recurrences.json
  def create
    @recurrence = Recurrence.new(recurrence_params)

    respond_to do |format|
      if @recurrence.save
        format.html { redirect_to @recurrence, notice: "Recurrence was successfully created." }
        format.json { render :show, status: :created, location: @recurrence }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @recurrence.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /recurrences/1 or /recurrences/1.json
  def update
    respond_to do |format|
      if @recurrence.update(recurrence_params)
        format.html { redirect_to @recurrence, notice: "Recurrence was successfully updated." }
        format.json { render :show, status: :ok, location: @recurrence }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @recurrence.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /recurrences/1 or /recurrences/1.json
  def destroy
    @recurrence.destroy!

    respond_to do |format|
      format.html { redirect_to recurrences_path, status: :see_other, notice: "Recurrence was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_recurrence
      @recurrence = Recurrence.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def recurrence_params
      params.expect(recurrence: [ :frequency, :interval, :ends_on ])
    end
end
