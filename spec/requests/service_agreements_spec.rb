require "rails_helper"

RSpec.describe "ServiceAgreements", type: :request do
  let!(:agreement) { create(:agreement, document_type: "service", active: true) }
  let!(:location)  { create(:location, email: "loc@example.com") }
  let!(:acceptance) do
    create(:location_agreement_acceptance, agreement: agreement, location: location)
  end

  describe "GET /service_agreements/:token" do
    it "renders the agreement for a valid token" do
      get service_agreement_path(acceptance.token)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(agreement.title)
    end

    it "404s for an invalid token" do
      get service_agreement_path("bad-token")
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /service_agreements/:token/accept" do
    it "marks acceptance signed and enqueues mail" do
      expect {
        post accept_service_agreement_path(acceptance.token), params: { agreement: { signed_name: "Jane Signer" } }
        acceptance.reload
      }.to change { acceptance.reload.signed_at.present? }.from(false).to(true)

      expect(enqueued_jobs_for(ActionMailer::MailDeliveryJob).size).to be >= 1
    end
  end

  describe "GET /service_agreements/:token/download" do
    it "requires signed; redirects if not signed" do
      get download_service_agreement_path(acceptance.token)
      expect(response).to have_http_status(:redirect)
    end

    it "sends a PDF when signed" do
      acceptance.update!(signed_name: "Jane Signer", signed_at: Time.current)
      get download_service_agreement_path(acceptance.token)
      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Type"]).to include("application/pdf")
    end
  end

  # Helper for counting specific enqueued jobs with ActiveJob test adapter
  def enqueued_jobs_for(job_class)
    ActiveJob::Base.queue_adapter.enqueued_jobs.select { |j| j[:job] == job_class }
  end
end
