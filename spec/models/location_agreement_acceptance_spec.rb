require "rails_helper"

RSpec.describe LocationAgreementAcceptance, type: :model do
  it { is_expected.to validate_presence_of(:content_hash) }

  it "generates a token on create" do
    laa = create(:location_agreement_acceptance)
    expect(laa.token).to be_present
  end

  it "knows when it is signed" do
    laa = build(:location_agreement_acceptance, signed_at: nil)
    expect(laa.signed?).to be false
    laa.signed_at = Time.current
    expect(laa.signed?).to be true
  end
end
