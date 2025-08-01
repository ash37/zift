json.extract! roster, :id, :starts_on, :status, :created_at, :updated_at
json.url roster_url(roster, format: :json)
