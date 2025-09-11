FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    name { "Test User" }
    role { User::ROLES[:employee] }
    status { User::STATUSES[:employee] }
    password { "Password1!" }
    password_confirmation { password }
  end
end
