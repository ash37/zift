require "rails_helper"

RSpec.describe "Agreements (employment)", type: :request do
  let!(:agreement) { create(:agreement, document_type: "employment", active: true) }
  let!(:user) { create(:user, email: "emp@example.com") }

  before { sign_in user }

  describe "GET /agreements/employment" do
    it "shows current agreement" do
      get agreement_path("employment")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(agreement.title)
    end
  end

  describe "POST /agreements/employment/accept" do
    it "creates an acceptance and enqueues mail" do
      expect {
        post accept_agreement_path("employment"), params: { agreement: { signed_name: "Emp User" } }
      }.to change { AgreementAcceptance.count }.by(1)

      expect(enqueued_jobs_for(ActionMailer::MailDeliveryJob).size).to be >= 1
    end
  end

  describe "GET /agreements/employment/download" do
    it "redirects if not signed" do
      get download_agreement_path("employment")
      expect(response).to have_http_status(:redirect)
    end

    it "downloads PDF when signed" do
      acceptance = AgreementAcceptance.create!(
        user: user,
        agreement: agreement,
        signed_name: "Emp User",
        signed_at: Time.current,
        ip_address: "127.0.0.1",
        user_agent: "RSpec",
        content_hash: agreement.content_hash
      )

      get download_agreement_path("employment")
      expect(response).to have_http_status(:ok)
      expect(response.headers["Content-Type"]).to include("application/pdf")
    end
  end

  def enqueued_jobs_for(job_class)
    ActiveJob::Base.queue_adapter.enqueued_jobs.select { |j| j[:job] == job_class }
  end
end

