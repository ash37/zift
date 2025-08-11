class UserMailer < ApplicationMailer
  def invitation_email
    @user = params[:user]
    @onboarding_url = accept_user_invitation_url(invitation_token: @user.invitation_token)
    mail(to: @user.email, subject: "You have been invited to join Qcare")
  end
end
