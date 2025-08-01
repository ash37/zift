require "test_helper"

class UnavailabilityRequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @unavailability_request = unavailability_requests(:one)
  end

  test "should get index" do
    get unavailability_requests_url
    assert_response :success
  end

  test "should get new" do
    get new_unavailability_request_url
    assert_response :success
  end

  test "should create unavailability_request" do
    assert_difference("UnavailabilityRequest.count") do
      post unavailability_requests_url, params: { unavailability_request: { ends_at: @unavailability_request.ends_at, reason: @unavailability_request.reason, starts_at: @unavailability_request.starts_at, status: @unavailability_request.status, user_id: @unavailability_request.user_id } }
    end

    assert_redirected_to unavailability_request_url(UnavailabilityRequest.last)
  end

  test "should show unavailability_request" do
    get unavailability_request_url(@unavailability_request)
    assert_response :success
  end

  test "should get edit" do
    get edit_unavailability_request_url(@unavailability_request)
    assert_response :success
  end

  test "should update unavailability_request" do
    patch unavailability_request_url(@unavailability_request), params: { unavailability_request: { ends_at: @unavailability_request.ends_at, reason: @unavailability_request.reason, starts_at: @unavailability_request.starts_at, status: @unavailability_request.status, user_id: @unavailability_request.user_id } }
    assert_redirected_to unavailability_request_url(@unavailability_request)
  end

  test "should destroy unavailability_request" do
    assert_difference("UnavailabilityRequest.count", -1) do
      delete unavailability_request_url(@unavailability_request)
    end

    assert_redirected_to unavailability_requests_url
  end
end
