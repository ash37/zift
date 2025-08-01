json.extract! location, :id, :name, :address, :latitude, :longitude, :allowed_radius, :created_at, :updated_at
json.url location_url(location, format: :json)
