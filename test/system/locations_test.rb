require "application_system_test_case"

class LocationsTest < ApplicationSystemTestCase
  setup do
    @location = locations(:one)
  end

  test "visiting the index" do
    visit locations_url
    assert_selector "h1", text: "Clients"
  end

  test "should create location" do
    visit locations_url
    click_on "Add"

    fill_in "Address", with: @location.address
    fill_in "Allowed radius", with: @location.allowed_radius
    fill_in "Latitude", with: @location.latitude
    fill_in "Longitude", with: @location.longitude
    fill_in "Name", with: @location.name
    click_on "Create Client"

    assert_text "Client was successfully created"
    click_on "Back"
  end

  test "should update Location" do
    visit location_url(@location)
    click_on "Edit", match: :first

    fill_in "Address", with: @location.address
    fill_in "Allowed radius", with: @location.allowed_radius
    fill_in "Latitude", with: @location.latitude
    fill_in "Longitude", with: @location.longitude
    fill_in "Name", with: @location.name
    click_on "Update Client"

    assert_text "Client was successfully updated"
    click_on "Back"
  end

  test "should destroy Location" do
    visit location_url(@location)
    accept_confirm { click_on "Archive", match: :first }

    assert_text "Client was successfully archived"
  end
end
