class IncidentMailer < ApplicationMailer
  layout false

  def notify_admin(incident)
    @incident = incident
    mail(to: "ak@qcare.au", subject: "New incident reported")
  end
end
