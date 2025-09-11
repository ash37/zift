FactoryBot.define do
  factory :location_agreement_acceptance do
    association :location
    association :agreement
    email { location.email }
    content_hash { agreement.content_hash }
  end
end

