json.extract! unavailability_request, :id, :user_id, :starts_at, :ends_at, :reason, :status, :created_at, :updated_at
json.url unavailability_request_url(unavailability_request, format: :json)
