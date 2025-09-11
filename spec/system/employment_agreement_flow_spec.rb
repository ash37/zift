require "rails_helper"

RSpec.describe "Employment agreement flow", type: :system do
  it "allows an employee to sign and download the agreement" do
    agreement = create(:agreement, document_type: "employment", title: "Employment Agreement", body: "<p>Terms</p>")
    user = create(:user, email: "emp@example.com", password: "Password1!", password_confirmation: "Password1!")

    login_as user, scope: :user

    visit agreement_path("employment")
    expect(page).to have_content("Employment Agreement")

    fill_in "agreement_signed_name", with: "Emp User"
    click_button "Accept"

    # After accepting, header shows Complete and a Download button
    expect(page).to have_content("Complete")
    expect(page).to have_link("Download PDF")
  end
end
