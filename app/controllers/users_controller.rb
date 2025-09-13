class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user, only: %i[ show edit update destroy employ contact archive restore ]
  before_action :set_user, only: %i[ remove_attachment remove_id_document ]

  # GET /users
  def index
    case params[:filter]
    when "applicants"
      @users = User.applicants
    when "contacted"
      @users = User.contacted
    when "ended"
      # Show users whose status is ended OR who are archived
      @users = User.with_archived.where("status = :ended OR archived_at IS NOT NULL", ended: User::STATUSES[:ended])
    else
      # Now correctly fetches all users with a role.
      @users = User.where.not(role: nil)
    end
  end

  # GET /users/1
  def show
    # Defensive: ensure @user is loaded even if before_action is skipped in some edge cases
    @user ||= User.with_archived.find_by(id: params[:id])
    unless @user
      redirect_to users_path, alert: "User not found" and return
    end
    @upcoming_shifts = @user.shifts.joins(:roster)
                              .where(rosters: { status: Roster::STATUSES[:published] })
                              .where("shifts.start_time >= ?", Time.current)
                              .order(:start_time)
                              .limit(5)
    @unavailability_requests = @user.unavailability_requests.where(status: 1).order(:starts_at)
  end

  # GET /users/new
  def new
    @user = User.new
  end

  # GET /users/1/edit
  def edit
    # Be explicit to ensure @user is set for the form partial
    @user ||= User.with_archived.find_by(id: params[:id])
    unless @user
      redirect_to users_path, alert: "User not found" and return
    end
  end

  # POST /users
  def create
    @user = User.new(user_params)
    # New users created by an admin are employees by default.
    @user.role ||= User::ROLES[:employee]

    if @user.save
      redirect_to @user, notice: "User was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

# PATCH/PUT /users/1
  def update
  # Ensure target user is loaded; fallback if before_action didn't set it
  @user ||= User.with_archived.find_by(id: params[:id])
  unless @user
    redirect_to users_path, alert: "User not found" and return
  end
  # Create a mutable copy of the parameters
  updated_params = user_params.to_h

  # Clean up the location_ids array to remove the blank value
  if updated_params[:location_ids]
    updated_params[:location_ids].reject!(&:blank?)
  end

  # Remove password params if they are blank, so we don't validate them
  if updated_params[:password].blank?
    updated_params.delete(:password)
    updated_params.delete(:password_confirmation)
  end

  # Extract multi-file attachments so we can append, not replace
  new_id_docs = updated_params.delete("id_documents") || updated_params.delete(:id_documents)

  if @user.update(updated_params)
    # Append new ID documents if provided (do not overwrite existing)
    if new_id_docs.present?
      Array(new_id_docs).reject(&:blank?).each do |doc|
        @user.id_documents.attach(doc)
      end
    end

    enqueue_attachment_optimization!
    redirect_to @user, notice: "User was successfully updated."
  else
    # This will print the validation errors to your terminal
    p @user.errors.full_messages
    render :edit, status: :unprocessable_entity
  end
end

  # DELETE /users/1
  def destroy
    @user.destroy!
    redirect_to users_url, notice: "User was successfully destroyed.", status: :see_other
  end

  # DELETE /users/:id/remove_attachment?name=:field
  def remove_attachment
    unless current_user == @user || current_user&.admin?
      redirect_to @user, alert: "Unauthorized" and return
    end
    name = params[:name].to_s
    allowed = %w[ ndis_screening_card ndis_orientation_certificate qcare_induction_certificate ]
    unless allowed.include?(name)
      redirect_to @user, alert: "Unknown attachment" and return
    end
    att = @user.public_send(name)
    if att.attached?
      att.purge
      redirect_to @user, notice: "Attachment removed."
    else
      redirect_to @user, alert: "No attachment to remove."
    end
  end

  # DELETE /users/:id/remove_id_document?signed_id=...
  def remove_id_document
    unless current_user == @user || current_user&.admin?
      redirect_to @user, alert: "Unauthorized" and return
    end
    signed_id = params[:signed_id].to_s
    attachment = @user.id_documents.attachments.find { |a| a.blob.signed_id == signed_id }
    if attachment
      attachment.purge
      redirect_to @user, notice: "ID document removed."
    else
      redirect_to @user, alert: "Document not found."
    end
  end

  # PATCH /users/:id/archive
  def archive
    # Ensure target user is loaded in case before_action didn't set it
    @user ||= User.with_archived.find_by(id: params[:id])
    unless @user
      redirect_to users_path, alert: "User not found" and return
    end
    unless current_user&.admin? || current_user&.manager?
      redirect_to @user, alert: "Unauthorized" and return
    end

    @user.update(archived_at: Time.current)
    redirect_to(users_path, notice: "User was successfully archived.")
  end

  # PATCH /users/:id/restore
  def restore
    # Ensure target user is loaded in case before_action didn't set it
    @user ||= User.with_archived.find_by(id: params[:id])
    unless @user
      redirect_to users_path, alert: "User not found" and return
    end
    unless current_user&.admin? || current_user&.manager?
      redirect_to @user, alert: "Unauthorized" and return
    end

    @user.update(archived_at: nil)
    redirect_to(user_path(@user), notice: "User was successfully restored.")
  end

  # POST /users/:id/employ
  def employ
    if @user.status == User::STATUSES[:applicant]
      @user.invitation_token = SecureRandom.urlsafe_base64
      @user.invitation_sent_at = Time.current
      @user.role = User::ROLES[:employee] # Assign the employee role
      @user.status = nil # Clear the applicant status
      @user.save!

      UserMailer.with(user: @user).invitation_email.deliver_later
      redirect_to @user, notice: "Employment email sent to #{@user.name}."
    else
      redirect_to @user, alert: "This user has already been processed."
    end
  end

  # POST /users/:id/contact
  def contact
    # Only admins may change status
    unless current_user && (current_user.respond_to?(:admin?) ? current_user.admin? : current_user&.role == "admin")
      redirect_to @user, alert: "Unauthorized" and return
    end

    # Update status to contacted without relying on mass-assignment
    target_value = if defined?(User::STATUSES) && User::STATUSES.is_a?(Hash) && User::STATUSES[:contacted]
                     User::STATUSES[:contacted]
    else
                     "contacted"
    end

    if @user.update(status: target_value)
      redirect_to(params[:redirect_to].presence || users_path(filter: "applicants"), notice: "User marked as contacted.")
    else
      redirect_to(params[:redirect_to].presence || users_path(filter: "applicants"), alert: @user.errors.full_messages.to_sentence)
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_user
      # Use with_archived so archive/restore and show can target archived users
      @user = User.with_archived.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def user_params
      # Safe fields any user can update on their own profile
      safe = [
        :name, :email, :phone, :gender,
        :obtained_screening, :date_of_birth, :address, :suburb, :state,
        :postcode, :emergency_name, :emergency_phone, :disability_experience,
        :other_experience, :other_employment, :licence, :availability, :bio,
        :known_client, :resident, :education, :qualification, :bank_account,
        :bsb, :tfn, :training, :departure, :yellow_expiry, :blue_expiry,
        :tfn_threshold, :debt, :super_name, :super_number,
        :password, :password_confirmation
      ]

      # Only admins can set privileged attributes
      if current_user&.respond_to?(:admin?) ? current_user.admin? : current_user&.role == "admin"
        safe += [ :role, :status, { location_ids: [] } ]
      end

      # File attachments (employee uploads)
      safe += [ :ndis_screening_card, :ndis_orientation_certificate, :qcare_induction_certificate, { id_documents: [] } ]

      # Be lenient: when some forms submit only attachments or no fields, avoid raising
      params.fetch(:user, {}).permit(safe)
    end

    def enqueue_attachment_optimization!
      # Enqueue optimization for any images; job will skip already-optimized
      [
        @user.ndis_screening_card,
        @user.ndis_orientation_certificate,
        @user.qcare_induction_certificate
      ].each do |att|
        AttachmentOptimizeJob.perform_later(att.attachment.id) if att.attached?
      end
      @user.id_documents.each do |att|
        AttachmentOptimizeJob.perform_later(att.id)
      end
    end
end
