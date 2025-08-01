json.extract! timesheet, :id, :user_id, :shift_id, :clock_in_at, :clock_out_at, :duration, :status, :created_at, :updated_at
json.url timesheet_url(timesheet, format: :json)
