require "rails_helper"

RSpec.describe "Locations service agreements", type: :request do
  let!(:admin) { create(:user, email: "admin@example.com", role: User::ROLES[:admin]) }
  let!(:agreement) { create(:agreement, document_type: "service", active: true) }
  let!(:location)  { create(:location, email: "loc@example.com", representative_email: "rep@example.com") }

  before { sign_in admin }

  describe "POST /locations/:id/send_service_agreement" do
    it "creates acceptance with location email and enqueues invite" do
      expect {
        post send_service_agreement_location_path(location)
      }.to change { LocationAgreementAcceptance.count }.by(1)

      laa = LocationAgreementAcceptance.order(created_at: :desc).first
      expect(laa.email).to eq(location.email)
      expect(enqueued_jobs_for(ActionMailer::MailDeliveryJob).size).to be >= 1
    end
  end

  describe "POST /locations/:id/resend_service_agreement" do
    it "updates emailed_at for existing pending acceptance and enqueues invite" do
      laa = LocationAgreementAcceptance.create!(location: location, agreement: agreement, email: location.email, content_hash: agreement.content_hash)
      sleep 0.01 # ensure timestamp change
      expect {
        post resend_service_agreement_location_path(location)
        laa.reload
      }.to change { laa.emailed_at.present? }.from(false).to(true)

      expect(LocationAgreementAcceptance.where(location: location, agreement: agreement).count).to eq(1)
      expect(enqueued_jobs_for(ActionMailer::MailDeliveryJob).size).to be >= 1
    end
  end

  def enqueued_jobs_for(job_class)
    ActiveJob::Base.queue_adapter.enqueued_jobs.select { |j| j[:job] == job_class }
  end
end
