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

    # Build a light acceptance-like object for PDF (userless), similar to controller
    acceptance_obj = OpenStruct.new(
      signed_name:  @acceptance.signed_name,
      signed_at:    @acceptance.signed_at,
      ip_address:   @acceptance.ip_address,
      user_agent:   @acceptance.user_agent,
      content_hash: @acceptance.content_hash,
      emailed_at:   @acceptance.emailed_at,
      user:         nil
    )
    pdf_data = AgreementPdf.render(@agreement, acceptance_obj, extra: { location: @location })

    attachments["service-agreement-#{@location.id}-v#{@agreement.version}.pdf"] = {
      mime_type: "application/pdf",
      content: pdf_data
    }

    # Always send to the location's primary email and BCC admin
    to_addr = @location.email.presence || "ak@qcare.au"
    mail(to: to_addr, bcc: "ak@qcare.au", subject: "Signed Service Agreement – #{@location.name}")
  end
end
