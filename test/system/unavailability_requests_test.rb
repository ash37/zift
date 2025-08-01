require "application_system_test_case"

class UnavailabilityRequestsTest < ApplicationSystemTestCase
  setup do
    @unavailability_request = unavailability_requests(:one)
  end

  test "visiting the index" do
    visit unavailability_requests_url
    assert_selector "h1", text: "Unavailability requests"
  end

  test "should create unavailability request" do
    visit unavailability_requests_url
    click_on "New unavailability request"

    fill_in "Ends at", with: @unavailability_request.ends_at
    fill_in "Reason", with: @unavailability_request.reason
    fill_in "Starts at", with: @unavailability_request.starts_at
    fill_in "Status", with: @unavailability_request.status
    fill_in "User", with: @unavailability_request.user_id
    click_on "Create Unavailability request"

    assert_text "Unavailability request was successfully created"
    click_on "Back"
  end

  test "should update Unavailability request" do
    visit unavailability_request_url(@unavailability_request)
    click_on "Edit this unavailability request", match: :first

    fill_in "Ends at", with: @unavailability_request.ends_at.to_s
    fill_in "Reason", with: @unavailability_request.reason
    fill_in "Starts at", with: @unavailability_request.starts_at.to_s
    fill_in "Status", with: @unavailability_request.status
    fill_in "User", with: @unavailability_request.user_id
    click_on "Update Unavailability request"

    assert_text "Unavailability request was successfully updated"
    click_on "Back"
  end

  test "should destroy Unavailability request" do
    visit unavailability_request_url(@unavailability_request)
    accept_confirm { click_on "Destroy this unavailability request", match: :first }

    assert_text "Unavailability request was successfully destroyed"
  end
end
