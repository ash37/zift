require "application_system_test_case"

class RecurrencesTest < ApplicationSystemTestCase
  setup do
    @recurrence = recurrences(:one)
  end

  test "visiting the index" do
    visit recurrences_url
    assert_selector "h1", text: "Recurrences"
  end

  test "should create recurrence" do
    visit recurrences_url
    click_on "New recurrence"

    fill_in "Ends on", with: @recurrence.ends_on
    fill_in "Frequency", with: @recurrence.frequency
    fill_in "Interval", with: @recurrence.interval
    click_on "Create Recurrence"

    assert_text "Recurrence was successfully created"
    click_on "Back"
  end

  test "should update Recurrence" do
    visit recurrence_url(@recurrence)
    click_on "Edit this recurrence", match: :first

    fill_in "Ends on", with: @recurrence.ends_on
    fill_in "Frequency", with: @recurrence.frequency
    fill_in "Interval", with: @recurrence.interval
    click_on "Update Recurrence"

    assert_text "Recurrence was successfully updated"
    click_on "Back"
  end

  test "should destroy Recurrence" do
    visit recurrence_url(@recurrence)
    accept_confirm { click_on "Destroy this recurrence", match: :first }

    assert_text "Recurrence was successfully destroyed"
  end
end
