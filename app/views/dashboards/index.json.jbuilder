# app/views/dashboards/index.json.jbuilder
# Expects @selected_date, @location (client’s assigned location), and @shifts
# to be set in DashboardsController#index for client users.

json.date do
  json.iso @selected_date.iso8601
  json.human @selected_date.strftime("%A - %d %b").upcase # e.g., "MONDAY - 28 AUG"
end

json.location do
  json.extract! @location, :id, :name
end

json.shifts @shifts do |shift|
  json.extract! shift, :id, :location_id, :area_id, :user_id
  json.start_time shift.start_time&.iso8601
  json.end_time   shift.end_time&.iso8601
  json.area_name  shift.area&.name
  json.user do
    json.id   shift.user&.id
    json.name (shift.user&.try(:full_name) || shift.user&.name)
  end

  # Include the first related timesheet (if any) for convenience
  ts = shift.try(:timesheets)&.first
  json.timesheet do
    if ts
      json.id           ts.id
      json.status       (ts.respond_to?(:status_name) ? ts.status_name : ts.status)
      json.clock_in_at  ts.clock_in_at&.iso8601
      json.clock_out_at ts.clock_out_at&.iso8601
      json.notes        ts.notes
      json.edit_url     Rails.application.routes.url_helpers.edit_timesheet_path(ts)
    else
      json.null!
    end
  end

  # Handy URLs for Shortcuts
  json.urls do
    # If there’s no timesheet yet, give a create-url as well
    if ts
      json.open Rails.application.routes.url_helpers.edit_timesheet_path(ts)
    else
      json.create Rails.application.routes.url_helpers.new_timesheet_path(shift_id: shift.id)
    end
    json.shift Rails.application.routes.url_helpers.shift_path(shift)
  end
end
