require "rails_helper"

RSpec.describe "Service agreement flow (public)", type: :system do
  it "allows a location to sign and then download the PDF" do
    agreement = create(:agreement, document_type: "service", title: "Service Agreement", body: "<p>Terms</p>")
    location  = create(:location, email: "loc@example.com")
    laa       = create(:location_agreement_acceptance, agreement: agreement, location: location)

    visit service_agreement_path(laa.token)
    expect(page).to have_content("Service Agreement")

    fill_in "agreement_signed_name", with: "Jane Doe"
    click_button "Accept"

    # After accepting, page shows signed details and a download link
    expect(page).to have_content("Accepted by Jane Doe")
    expect(page).to have_link("Download PDF")
  end
end
