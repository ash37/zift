require "rails_helper"

RSpec.describe ServiceAgreementMailer, type: :mailer do
  let(:location)  { create(:location, email: "loc@example.com", representative_email: "rep@example.com") }
  let(:agreement) { create(:agreement, document_type: "service") }
  let(:acceptance) do
    create(:location_agreement_acceptance, location: location, agreement: agreement, email: "override@example.com")
  end

  describe "invite" do
    it "sends to location.email only" do
      mail = described_class.with(acceptance: acceptance).invite
      expect(mail.to).to eq([ "loc@example.com" ]) # no representative or acceptance email fallback
    end
  end

  describe "signed" do
    it "bccs ak@qcare.au and sends to location.email" do
      mail = described_class.with(acceptance: acceptance, pdf_data: "PDF").signed
      expect(mail.to).to eq([ "loc@example.com" ]) # to address
      expect(Array(mail.bcc)).to include("ak@qcare.au") # bcc present
    end
  end
end
