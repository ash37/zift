# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
location = Location.create!(
  name: "Head Office",
  address: "123 Admin Way",
  latitude: 0.0,
  longitude: 0.0,
  allowed_radius: 100
)

User.create!(
  name: "Ashley Knight",
  email: "ak@qcare.au",
  password: "password",
  password_confirmation: "password",
  role: :admin,
  locations: [ location ]
)

# Create Shift Types for Xero Mapping
[ 'Weekday', 'Weeknight (first 2 hours)', 'Weeknight (after 2 hours)', 'Saturday', 'Sunday', 'Public Holiday' ].each do |name|
  ShiftType.find_or_create_by!(name: name)
end
