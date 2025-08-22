# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
locations_data = [
  { name: "Darren Jeacocke", address: "Unit 10 / 48 Latrobe St, Tannum Sands" },
  { name: "Emily McGuire", address: "Unit 4 / 151C Murray St, Rockhampton" },
  { name: "Hayden Shaw", address: "1 Kerr St, Park Avenue" },
  { name: "Jeremy Deamon", address: "27 Melbourne St, West Rockhampton" },
  { name: "Lachlan Gyer", address: "300A Blanchfield St, Koongal" },
  { name: "Milton Couchy", address: "195 Philips St, Berserker" },
  { name: "Nichola Ryan", address: "39 Denison St, Rockhampton" },
  { name: "Nikki Wood", address: "129 West St, Allenstown" },
  { name: "Robbie Emery", address: "61 John St, Emu Park" }
]

locations = locations_data.map do |loc_attrs|
  Location.find_or_create_by!(name: loc_attrs[:name]) do |loc|
    loc.address        = loc_attrs[:address]
    loc.latitude       = nil
    loc.longitude      = nil
    loc.allowed_radius = 1000
  end
end

user = User.find_or_create_by!(email: "ak@qcare.au") do |u|
  u.name                  = "Ashley Knight"
  u.password              = "password"
  u.password_confirmation = "password"
  u.role                  = User::ROLES[:admin]
end
user.locations << locations.first if user.locations.blank?

# Create Shift Types for Xero Mapping

[ 'Weekday', 'Weeknight (first 2 hours)', 'Weeknight (after 2 hours)', 'Saturday', 'Sunday', 'Public Holiday', 'Travel', 'Saturday Night', 'Sunday Night' ].each do |name|
  ShiftType.find_or_create_by!(name: name)
end

# Create default Shift Questions
shift_questions_data = [
  { question_text: "Any bowel issues on this shift", question_type: "post_shift_yn", display_order: 1, is_mandatory: false, is_active: true },
  { question_text: "Did an incident occur on this shift", question_type: "post_shift_yn", display_order: 1, is_mandatory: false, is_active: true }
]

shift_questions_data.each do |attrs|
  ShiftQuestion.find_or_create_by!(question_text: attrs[:question_text]) do |q|
    q.question_type = attrs[:question_type]
    q.display_order = attrs[:display_order]
    q.is_mandatory  = attrs[:is_mandatory]
    q.is_active     = attrs[:is_active]
  end
end
