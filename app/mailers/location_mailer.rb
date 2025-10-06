class LocationMailer < ApplicationMailer
  layout false

  def new_participant(location)
    @location = location
    mail(to: "ak@qcare.au", subject: "New Participant")
  end
end
