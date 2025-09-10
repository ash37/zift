class ServiceAgreementMailer < ApplicationMailer
  def invite
    @acceptance = params[:acceptance]
    @location   = @acceptance.location
    @agreement  = @acceptance.agreement
    @url = service_agreement_url(@acceptance.token)

    # Always send to the location's primary email
    mail(to: @location.email, subject: "Service Agreement – #{@location.name}")
  end

  def signed
    @acceptance = params[:acceptance]
    @location   = @acceptance.location
    @agreement  = @acceptance.agreement
    pdf_data    = params[:pdf_data]

    attachments["service-agreement-#{@location.id}-v#{@agreement.version}.pdf"] = {
      mime_type: "application/pdf",
      content: pdf_data
    }

    # Always send to the location's primary email
    mail(to: @location.email, subject: "Signed Service Agreement – #{@location.name}")
  end
end
