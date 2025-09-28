module LocationsHelper
  def location_compliance_status(location, current_service_agreement = nil)
    missing = []

    begin
      signed = if current_service_agreement.present?
                 LocationAgreementAcceptance.where(location: location, agreement: current_service_agreement)
                                             .where.not(signed_at: nil)
                                             .exists?
               else
                 LocationAgreementAcceptance.joins(:agreement)
                                             .where(location: location, agreements: { document_type: 'service' })
                                             .where.not(signed_at: nil)
                                             .exists?
               end
      missing << 'Service agreement not signed' unless signed

      support_plan_ok = location.support_plan.attached?
      missing << 'Support plan missing' unless support_plan_ok

      risk_assessment_ok = location.risk_assessment.attached?
      missing << 'Risk assessment missing' unless risk_assessment_ok

      [missing.empty?, missing]
    rescue StandardError
      [false, ['Status unavailable']]
    end
  end
end
