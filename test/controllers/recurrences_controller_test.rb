require "test_helper"

class RecurrencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @recurrence = recurrences(:one)
  end

  test "should get index" do
    get recurrences_url
    assert_response :success
  end

  test "should get new" do
    get new_recurrence_url
    assert_response :success
  end

  test "should create recurrence" do
    assert_difference("Recurrence.count") do
      post recurrences_url, params: { recurrence: { ends_on: @recurrence.ends_on, frequency: @recurrence.frequency, interval: @recurrence.interval } }
    end

    assert_redirected_to recurrence_url(Recurrence.last)
  end

  test "should show recurrence" do
    get recurrence_url(@recurrence)
    assert_response :success
  end

  test "should get edit" do
    get edit_recurrence_url(@recurrence)
    assert_response :success
  end

  test "should update recurrence" do
    patch recurrence_url(@recurrence), params: { recurrence: { ends_on: @recurrence.ends_on, frequency: @recurrence.frequency, interval: @recurrence.interval } }
    assert_redirected_to recurrence_url(@recurrence)
  end

  test "should destroy recurrence" do
    assert_difference("Recurrence.count", -1) do
      delete recurrence_url(@recurrence)
    end

    assert_redirected_to recurrences_url
  end
end
