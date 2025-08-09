class RosterMailer < ApplicationMailer
  def roster_published
    @user = params[:user]
    @roster = params[:roster]
    @shifts = @roster.shifts.where(user: @user).order(:start_time)

    mail(to: @user.email, subject: "Your roster for the week of #{@roster.starts_on.strftime('%B %d')}")
  end
end
