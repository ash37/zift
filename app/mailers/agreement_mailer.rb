class AgreementMailer < ApplicationMailer
  def signed
    @user       = params[:user]
    @agreement  = params[:agreement]
    @acceptance = params[:acceptance]
    location    = params[:location]

    # Render PDF inside the mailer to avoid enqueueing binary data in the job
    pdf_data = AgreementPdf.render(@agreement, @acceptance, extra: { location: location })

    attachments["#{@agreement.document_type}-agreement-#{@agreement.version}.pdf"] = {
      mime_type: "application/pdf",
      content: pdf_data
    }

    mail(to: @user.email, subject: "Your #{@agreement.document_type.titleize} Agreement (v#{@agreement.version})")
  end
end
