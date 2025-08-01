require "application_system_test_case"

class ShiftsTest < ApplicationSystemTestCase
  setup do
    @shift = shifts(:one)
  end

  test "visiting the index" do
    visit shifts_url
    assert_selector "h1", text: "Shifts"
  end

  test "should create shift" do
    visit shifts_url
    click_on "New shift"

    fill_in "End time", with: @shift.end_time
    fill_in "Location", with: @shift.location_id
    fill_in "Recurrence", with: @shift.recurrence_id
    fill_in "Roster", with: @shift.roster_id
    fill_in "Start time", with: @shift.start_time
    fill_in "User", with: @shift.user_id
    click_on "Create Shift"

    assert_text "Shift was successfully created"
    click_on "Back"
  end

  test "should update Shift" do
    visit shift_url(@shift)
    click_on "Edit this shift", match: :first

    fill_in "End time", with: @shift.end_time.to_s
    fill_in "Location", with: @shift.location_id
    fill_in "Recurrence", with: @shift.recurrence_id
    fill_in "Roster", with: @shift.roster_id
    fill_in "Start time", with: @shift.start_time.to_s
    fill_in "User", with: @shift.user_id
    click_on "Update Shift"

    assert_text "Shift was successfully updated"
    click_on "Back"
  end

  test "should destroy Shift" do
    visit shift_url(@shift)
    accept_confirm { click_on "Destroy this shift", match: :first }

    assert_text "Shift was successfully destroyed"
  end
end
