require "ostruct"

class ServiceAgreementsController < ApplicationController
  layout "application"
  skip_before_action :authenticate_user!

  before_action :set_acceptance

  def show
    @agreement = @acceptance.agreement
    @location  = @acceptance.location
  end

  def accept
    signed_name = params.require(:agreement).permit(:signed_name)[:signed_name]
    if signed_name.blank?
      redirect_to service_agreement_path(@acceptance.token), alert: "Please enter your legal name." and return
    end

    @acceptance.update!(
      signed_name: signed_name,
      signed_at: Time.current,
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )

    # Build a light acceptance-like object for PDF (userless)
    acceptance_obj = OpenStruct.new(
      signed_name: @acceptance.signed_name,
      signed_at: @acceptance.signed_at,
      ip_address: @acceptance.ip_address,
      user_agent: @acceptance.user_agent,
      user: nil
    )

    pdf_data = AgreementPdf.render(@acceptance.agreement, acceptance_obj, extra: { location: @acceptance.location })
    ServiceAgreementMailer.with(acceptance: @acceptance, pdf_data: pdf_data).signed.deliver_later

    redirect_to service_agreement_path(@acceptance.token), notice: "Agreement accepted. A copy has been emailed."
  end

  private
  def set_acceptance
    @acceptance = LocationAgreementAcceptance.find_by!(token: params[:token])
  end
end
