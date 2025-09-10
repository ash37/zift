class AgreementMailer < ApplicationMailer
  def signed
    @user = params[:user]
    @agreement = params[:agreement]
    @acceptance = params[:acceptance]
    pdf_data = params[:pdf_data]

    attachments["#{@agreement.document_type}-agreement-#{@agreement.version}.pdf"] = {
      mime_type: "application/pdf",
      content: pdf_data
    }

    mail(to: @user.email, subject: "Your #{@agreement.document_type.titleize} Agreement (v#{@agreement.version})")
  end
end
