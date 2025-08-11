class ApplicationsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :new, :create, :success ]

  def new
    @user = User.new
  end

  def create
    @user = User.new(application_params)
    @user.status = User::STATUSES[:applicant]

    if @user.save
      redirect_to success_applications_path
    else
      render :new, status: :unprocessable_content
    end
  end

  def success
    # This action just renders the success page
  end

  private

  def application_params
    params.require(:user).permit(:name, :email, :phone)
  end
end
