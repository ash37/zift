FactoryBot.define do
  factory :agreement do
    document_type { "service" }
    sequence(:version) { |n| n }
    title { "Test Agreement" }
    body { "<p><strong>Terms</strong> and conditions.</p>" }
    active { true }
  end
end
