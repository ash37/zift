require "application_system_test_case"

class TimesheetsTest < ApplicationSystemTestCase
  setup do
    @timesheet = timesheets(:one)
  end

  test "visiting the index" do
    visit timesheets_url
    assert_selector "h1", text: "Timesheets"
  end

  test "should create timesheet" do
    visit timesheets_url
    click_on "New timesheet"

    fill_in "Clock in at", with: @timesheet.clock_in_at
    fill_in "Clock out at", with: @timesheet.clock_out_at
    fill_in "Duration", with: @timesheet.duration
    fill_in "Shift", with: @timesheet.shift_id
    fill_in "Status", with: @timesheet.status
    fill_in "User", with: @timesheet.user_id
    click_on "Create Timesheet"

    assert_text "Timesheet was successfully created"
    click_on "Back"
  end

  test "should update Timesheet" do
    visit timesheet_url(@timesheet)
    click_on "Edit this timesheet", match: :first

    fill_in "Clock in at", with: @timesheet.clock_in_at.to_s
    fill_in "Clock out at", with: @timesheet.clock_out_at.to_s
    fill_in "Duration", with: @timesheet.duration
    fill_in "Shift", with: @timesheet.shift_id
    fill_in "Status", with: @timesheet.status
    fill_in "User", with: @timesheet.user_id
    click_on "Update Timesheet"

    assert_text "Timesheet was successfully updated"
    click_on "Back"
  end

  test "should destroy Timesheet" do
    visit timesheet_url(@timesheet)
    accept_confirm { click_on "Destroy this timesheet", match: :first }

    assert_text "Timesheet was successfully destroyed"
  end
end
