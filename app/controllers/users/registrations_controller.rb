class Users::RegistrationsController < Devise::RegistrationsController
  skip_before_action :authenticate_user!, only: [ :edit, :update ]
  skip_before_action :authenticate_scope!, only: [ :edit, :update ]
  # This action is triggered by the link in the invitation email.
  # It finds the user by the token and shows the form to set a password.
  def edit
    @token = params[:invitation_token]
    @user  = User.find_by(invitation_token: @token)

    if @user.blank? || @user.invitation_sent_at.blank? || @user.invitation_sent_at < 72.hours.ago
      redirect_to new_user_session_path, alert: "Your invitation token is invalid or has expired."
      return
    end

    # Don't call super; this path is for users who aren't signed in yet.
    self.resource = @user
    render :edit
  end

  # This action is triggered when the new employee submits the form.
  def update
    @user = User.find_by(invitation_token: user_params[:invitation_token])

    if @user.nil?
      redirect_to new_user_session_path, alert: "Your invitation token is invalid or has expired." and return
    end

    if @user.update(user_params)
      # Invalidate the token after use
      @user.update(invitation_token: nil, invitation_sent_at: nil)
      sign_in(@user)
      redirect_to dashboards_path, notice: "Your account has been successfully set up!"
    else
      self.resource = @user
      render :edit, status: :unprocessable_entity
    end
  end

  private

  # Use the strong params from your users_controller
  def user_params
    params.require(:user).permit(
      :password, :password_confirmation, :invitation_token,
      :name, :email, :phone, :role, :location_id, :status, :gender,
      :obtained_screening, :date_of_birth, :address, :suburb, :state,
      :postcode, :emergency_name, :emergency_phone, :disability_experience,
      :other_experience, :other_employment, :licence, :availability, :bio,
      :known_client, :resident, :education, :qualification, :bank_account,
      :bsb, :tfn, :training, :departure, :yellow_expiry, :blue_expiry,
      :tfn_threshold, :debt, :super_name, :super_number
    )
  end
end
