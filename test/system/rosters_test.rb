require "application_system_test_case"

class RostersTest < ApplicationSystemTestCase
  setup do
    @roster = rosters(:one)
  end

  test "visiting the index" do
    visit rosters_url
    assert_selector "h1", text: "Rosters"
  end

  test "should create roster" do
    visit rosters_url
    click_on "New roster"

    fill_in "Starts on", with: @roster.starts_on
    fill_in "Status", with: @roster.status
    click_on "Create Roster"

    assert_text "Roster was successfully created"
    click_on "Back"
  end

  test "should update Roster" do
    visit roster_url(@roster)
    click_on "Edit this roster", match: :first

    fill_in "Starts on", with: @roster.starts_on
    fill_in "Status", with: @roster.status
    click_on "Update Roster"

    assert_text "Roster was successfully updated"
    click_on "Back"
  end

  test "should destroy Roster" do
    visit roster_url(@roster)
    accept_confirm { click_on "Destroy this roster", match: :first }

    assert_text "Roster was successfully destroyed"
  end
end
