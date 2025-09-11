class AgreementsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_employee_or_admin!, only: [ :show, :accept ], if: -> { params[:document_type] == "employment" }

  def show
    @document_type = params[:document_type]
    @agreement = Agreement.current_for(@document_type)
    @location = Location.with_archived.find(params[:location_id]) if params[:location_id].present? rescue nil
    if @agreement.nil?
      redirect_to root_path, alert: "No #{@document_type} agreement found." and return
    end

    # Allow admins to view agreement as any user (via user_id), others see their own
    @subject_user = if current_user&.admin? && params[:user_id].present?
                      User.with_archived.find_by(id: params[:user_id]) || current_user
    else
                      current_user
    end

    @acceptance = AgreementAcceptance.find_by(user: @subject_user, agreement: @agreement)
  end

  def accept
    @document_type = params[:document_type]
    @agreement = Agreement.current_for(@document_type)
    @location = Location.with_archived.find(params[:location_id]) if params[:location_id].present? rescue nil
    if @agreement.nil?
      redirect_to root_path, alert: "No #{@document_type} agreement found." and return
    end

    if AgreementAcceptance.exists?(user: current_user, agreement: @agreement)
      redirect_to agreement_path(@document_type), notice: "Agreement already accepted." and return
    end

    signed_name = params.require(:agreement).permit(:signed_name)[:signed_name]
    if signed_name.blank?
      redirect_to agreement_path(@document_type), alert: "Please enter your legal name." and return
    end

    acceptance = AgreementAcceptance.new(
      user: current_user,
      agreement: @agreement,
      signed_name: signed_name,
      signed_at: Time.current,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      content_hash: @agreement.content_hash
    )

    if acceptance.save
      pdf_data = AgreementPdf.render(@agreement, acceptance, extra: { location: @location })
      AgreementMailer.with(user: current_user, agreement: @agreement, acceptance: acceptance, pdf_data: pdf_data).signed.deliver_later
      redirect_to agreement_path(@document_type, location_id: @location&.id), notice: "Agreement accepted. A copy has been emailed to you."
    else
      redirect_to agreement_path(@document_type, location_id: @location&.id), alert: acceptance.errors.full_messages.to_sentence
    end
  end

  def download
    @document_type = params[:document_type]
    @agreement = Agreement.current_for(@document_type)
    if @agreement.nil?
      redirect_to root_path, alert: "No #{@document_type} agreement found." and return
    end

    # Pick the subject user similarly to show
    subject_user = if current_user&.admin? && params[:user_id].present?
                     User.with_archived.find_by(id: params[:user_id]) || current_user
                   else
                     current_user
                   end

    acceptance = AgreementAcceptance.find_by(user: subject_user, agreement: @agreement)
    if acceptance.blank? || acceptance.signed_at.blank?
      redirect_to agreement_path(@document_type, user_id: subject_user&.id), alert: "Agreement is not yet signed." and return
    end

    pdf_data = AgreementPdf.render(@agreement, acceptance, extra: {})
    filename = "#{@agreement.document_type}-agreement-#{subject_user.id}-v#{@agreement.version}.pdf"
    send_data pdf_data, filename: filename, type: "application/pdf", disposition: "attachment"
  end

  private
  def require_employee_or_admin!
    unless current_user&.employee? || current_user&.admin?
      redirect_to root_path, alert: "Unauthorized"
    end
  end
end
