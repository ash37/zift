FactoryBot.define do
  factory :agreement_acceptance do
    association :user
    association :agreement
    signed_name { "John Tester" }
    signed_at { Time.current }
    ip_address { "127.0.0.1" }
    user_agent { "RSpec" }
    content_hash { agreement.content_hash }
  end
end

