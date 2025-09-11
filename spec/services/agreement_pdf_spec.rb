require "rails_helper"

RSpec.describe AgreementPdf do
  it "renders a non-empty PDF" do
    agreement = create(:agreement, title: "Sample", body: "<p><strong>Body</strong> text<br>line 2</p>")
    user = create(:user)
    acceptance = build(:agreement_acceptance, user: user, agreement: agreement)
    pdf = described_class.render(agreement, acceptance, extra: {})
    expect(pdf).to be_a(String)
    expect(pdf.bytesize).to be > 1000
  end
end

