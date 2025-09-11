FactoryBot.define do
  factory :location do
    sequence(:name) { |n| "Location #{n}" }
    email { "location@example.com" }
    address { "1 Test St" }
  end
end
