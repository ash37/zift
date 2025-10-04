class ApplicationsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :new, :create, :success ]

  def new
    @application = User.new
  end

  def create
    @application = User.new(application_params)
    if @application.password.blank?
      generated_password = Devise.friendly_token.first(20)
      @application.password = generated_password
      @application.password_confirmation = generated_password
    end
    if defined?(User::STATUSES) && User::STATUSES.respond_to?(:[]) && User::STATUSES[:applicant]
      @application.status = User::STATUSES[:applicant]
    end

    if @application.save
      ApplicantMailer.notify_new_applicant(@application).deliver_later
      ApplicantMailer.acknowledge_applicant(@application).deliver_later if @application.email.present?
      redirect_to success_applications_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def success
    # This action just renders the success page
  end

  private

  # NOTE: The public form currently posts under params[:user]. We accept that here
  # to avoid changing the view right now. If you later switch the form builder to
  # `model: @application`, also update this to `params.require(:application)`.
  def application_params
    params.require(:user).permit(
      :name, :email, :phone, :obtained_screening, :date_of_birth,
      :suburb, :postcode, :disability_experience, :other_employment,
      :licence, :availability
    )
  end
end
