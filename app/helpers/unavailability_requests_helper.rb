# app/helpers/unavailability_requests_helper.rb
module UnavailabilityRequestsHelper
  # Generates an array of times in 30-minute increments for a select dropdown.
  # The display text is in AM/PM format (e.g., "9:30 AM"),
  # while the submission value is in 24-hour format (e.g., "09:30").
  def time_options_for_select
    start_time = Time.zone.now.beginning_of_day
    end_time = Time.zone.now.end_of_day
    time_options = []
    current_time = start_time

    while current_time < end_time
      display_time = current_time.strftime("%-l:%M %p").strip
      value_time = current_time.strftime("%H:%M")
      time_options << [ display_time, value_time ]
      current_time += 30.minutes
    end

    time_options
  end

  # Helper to get the initial selected value for the dropdown,
  # rounded to the nearest 30 minutes.
  def selected_time_for(datetime)
    return nil if datetime.blank?

    # Rounds the time to the nearest half-hour (1800 seconds)
    rounded_time = Time.at((datetime.to_i / 1800.0).round * 1800)
    rounded_time.strftime("%H:%M")
  end
end
