class ApplicantMailer < ApplicationMailer
  layout false

  def notify_new_applicant(user)
    @applicant = user
    mail(to: "ak@qcare.au", subject: "New applicant")
  end

  def acknowledge_applicant(user)
    @applicant = user
    mail(to: @applicant.email, subject: "Application Received")
  end
end
