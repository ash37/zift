json.extract! recurrence, :id, :frequency, :interval, :ends_on, :created_at, :updated_at
json.url recurrence_url(recurrence, format: :json)
