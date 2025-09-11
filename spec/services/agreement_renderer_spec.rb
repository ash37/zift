require "rails_helper"

RSpec.describe AgreementRenderer do
  it "replaces user, date, acceptance, and location placeholders" do
    user = create(:user, name: "Alex Smith", email: "alex@example.com")
    agreement = create(:agreement, body: "<p>Hello {{ user.first_name }} at {{ location.name }} on {{ date.today }}. Signed: {{ acceptance.signed_name }}</p>")
    location = create(:location, name: "Loc One", email: "loc@example.com")
    acceptance = build(:agreement_acceptance, user: user, agreement: agreement, signed_name: "Alex Smith")

    rendered = described_class.render(agreement, user: user, acceptance: acceptance, extra: { location: location })
    expect(rendered).to include("Hello Alex")
    expect(rendered).to include("Loc One")
    expect(rendered).to include("Signed: Alex Smith")
  end
end

