class ComplianceMailer < ApplicationMailer
  def reminder
    @user = params[:user]
    @body = params[:body]
    mail(to: 'ak@qcare.au', subject: params[:subject]) do |format|
      format.text { render plain: @body }
      format.html { render html: view_context.simple_format(@body).html_safe }
    end
  end
end

