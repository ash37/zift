class UnavailabilityMailer < ApplicationMailer
  layout false

  def new_request_notification(request)
    @request = request
    @user    = request.user
    mail(to: "ak@qcare.au", subject: "New unavailability request")
  end
end
