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
      content_hash: @acceptance.content_hash,
      emailed_at: @acceptance.emailed_at,
      user: nil
    )

    pdf_data = AgreementPdf.render(@acceptance.agreement, acceptance_obj, extra: { location: @acceptance.location })
    mailer = ServiceAgreementMailer.with(acceptance: @acceptance, pdf_data: pdf_data).signed
    begin
      mailer.deliver_later
    rescue => e
      Rails.logger.error("Failed to enqueue signed agreement email: #{e.class}: #{e.message}") if defined?(Rails)
      # Fallback to synchronous delivery to avoid losing the email
      mailer.deliver_now
    end

    redirect_to service_agreement_path(@acceptance.token), notice: "Agreement accepted. A copy has been emailed."
  end

  def download
    unless @acceptance.signed_at.present?
      redirect_to service_agreement_path(@acceptance.token), alert: "Agreement is not yet signed." and return
    end

    acceptance_obj = OpenStruct.new(
      signed_name: @acceptance.signed_name,
      signed_at: @acceptance.signed_at,
      ip_address: @acceptance.ip_address,
      user_agent: @acceptance.user_agent,
      content_hash: @acceptance.content_hash,
      emailed_at: @acceptance.emailed_at,
      user: nil
    )

    pdf_data = AgreementPdf.render(@acceptance.agreement, acceptance_obj, extra: { location: @acceptance.location })
    filename = "service-agreement-#{@acceptance.location.id}-v#{@acceptance.agreement.version}.pdf"
    send_data pdf_data, filename: filename, type: "application/pdf", disposition: "attachment"
  end

  private
  def set_acceptance
    @acceptance = LocationAgreementAcceptance.find_by!(token: params[:token])
  end
end
