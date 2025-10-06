class LocationsController < ApplicationController
  before_action :authenticate_user!, except: %i[new create intake_details intake_details_update intake_success]
  before_action :set_location, only: %i[ show edit update destroy archive restore send_service_agreement resend_service_agreement remove_attachment ]
  before_action :set_location_from_token, only: %i[intake_details intake_details_update]

  # GET /locations or /locations.json
  def index
    @status_filter = params[:status].presence

    @locations = case @status_filter
                 when 'prospect'
                   Location.ordered_by_name.prospects
                 when 'archived'
                   Location.archived.ordered_by_name
                 else
                   Location.ordered_by_name.active_status
                 end
  end

  # GET /locations/1 or /locations/1.json
  def show
    @area = Area.new(location: @location)
    @areas = @location.areas
  end

  # GET /locations/new
  def new
    if user_signed_in?
      @location = Location.new
      @location.areas.build
    else
      @location = Location.new
      @location.public_intake = true
      @current_step = :basic
      render :public_new
    end
  end

  # GET /locations/1/edit
  def edit
    @location.areas.build if @location.areas.empty?
  end

  # POST /locations or /locations.json
  def create
    if user_signed_in?
      @location = Location.new(location_params)

      respond_to do |format|
        if @location.save
          format.html { redirect_to locations_url, notice: "Client was successfully created." }
          format.json { render :show, status: :created, location: @location }
        else
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: @location.errors, status: :unprocessable_entity }
        end
      end
    else
      @location = Location.new(public_step_one_params)
      @location.public_intake = true
      @location.status = Location::STATUSES[:prospect]

      if @location.save
        LocationMailer.new_participant(@location).deliver_later
        redirect_to intake_details_locations_path(token: @location.signed_id(purpose: :location_intake))
      else
        @current_step = :basic
        render :public_new, status: :unprocessable_entity
      end
    end
  end

  # PATCH/PUT /locations/1 or /locations/1.json
  def update
    respond_to do |format|
      if @location.update(location_params)
        enqueue_attachment_optimization!
        format.html { redirect_to location_url(@location), notice: "Client was successfully updated." }
        format.json { render :show, status: :ok, location: @location }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @location.errors, status: :unprocessable_entity }
      end
    end
  end

  def intake_details
    @location.public_intake = true
    @current_step = :details
  end

  def intake_details_update
    @location.public_intake = true
    if @location.update(public_step_two_params)
      redirect_to intake_success_locations_path
    else
      @current_step = :details
      render :intake_details, status: :unprocessable_entity
    end
  end

  def intake_success; end

  # DELETE /locations/1 or /locations/1.json
  def destroy
    @location.destroy!

    respond_to do |format|
      format.html { redirect_to locations_url, notice: "Client was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def archive
    @location.update(archived_at: Time.current)
    redirect_to locations_url, notice: "Client was successfully archived."
  end

  def restore
    @location.update(archived_at: nil)
    redirect_to locations_url, notice: "Client was successfully restored."
  end

  def remove_attachment
    unless current_user&.admin? || current_user&.manager?
      redirect_to @location, alert: "Unauthorized" and return
    end

    name = params[:name].to_s
    allowed = %w[support_plan risk_assessment]
    unless allowed.include?(name)
      redirect_to @location, alert: "Unknown attachment" and return
    end

    attachment = @location.public_send(name)
    if attachment.attached?
      attachment.purge
      redirect_to @location, notice: "Attachment removed."
    else
      redirect_to @location, alert: "No attachment to remove."
    end
  end

  def send_service_agreement
    unless current_user&.admin?
      redirect_to @location, alert: "Unauthorized" and return
    end
    agreement = Agreement.current_for("service")
    if agreement.nil?
      redirect_to @location, alert: "No active service agreement configured." and return
    end

    acceptance = LocationAgreementAcceptance.create!(
      location: @location,
      agreement: agreement,
      # Store the location's email for record, but we will always mail to location.email
      email: @location.email,
      content_hash: agreement.content_hash,
      emailed_at: Time.current
    )

    ServiceAgreementMailer.with(acceptance: acceptance).invite.deliver_later
    redirect_to @location, notice: "Service agreement link sent."
  end

  def resend_service_agreement
    unless current_user&.admin?
      redirect_to @location, alert: "Unauthorized" and return
    end
    agreement = Agreement.current_for("service")
    if agreement.nil?
      redirect_to @location, alert: "No active service agreement configured." and return
    end

    acceptance = LocationAgreementAcceptance.where(location: @location, agreement: agreement, signed_at: nil)
                                            .order(created_at: :desc)
                                            .first

    if acceptance.present?
      # Refresh the stored email to the current location email and bump emailed_at
      acceptance.update(emailed_at: Time.current, email: @location.email)
      ServiceAgreementMailer.with(acceptance: acceptance).invite.deliver_later
      redirect_to @location, notice: "Service agreement link re-sent."
    else
      # No pending acceptance; create a fresh one
      acceptance = LocationAgreementAcceptance.create!(
        location: @location,
        agreement: agreement,
        email: @location.email,
        content_hash: agreement.content_hash,
        emailed_at: Time.current
      )
      ServiceAgreementMailer.with(acceptance: acceptance).invite.deliver_later
      redirect_to @location, notice: "Service agreement link sent."
    end
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
        :support_plan,
        :risk_assessment,
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

    def public_step_one_params
      params.require(:location).permit(:name, :email, :phone)
    end

    def public_step_two_params
      params.require(:location).permit(
        :address,
        :date_of_birth,
        :gender,
        :ndis_number,
        :representative_name,
        :representative_email,
        :phone,
        :email,
        :funding,
        :plan_manager_email,
        :activities_of_interest,
        :tasks,
        :lives_with,
        :pets
      )
    end

    def set_location_from_token
      token = params[:token].to_s
      @location = Location.find_signed(token, purpose: :location_intake)
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
      redirect_to new_location_path, alert: "The link you used has expired. Please start again." and return
    end

    def enqueue_attachment_optimization!
      [
        @location.support_plan,
        @location.risk_assessment
      ].each do |att|
        AttachmentOptimizeJob.perform_later(att.attachment.id) if att.respond_to?(:attachment) && att.attached?
      end
    end
end
