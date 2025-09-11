require "rails_helper"

RSpec.describe Agreement, type: :model do
  it { is_expected.to validate_inclusion_of(:document_type).in_array(%w[employment service]) }
  it { is_expected.to validate_presence_of(:title) }
  it { is_expected.to validate_presence_of(:body) }

  describe "#content_hash" do
    it "changes when body changes" do
      agreement = build(:agreement, body: "One")
      first_hash = agreement.content_hash
      agreement.body = "Two"
      expect(agreement.content_hash).not_to eq(first_hash)
    end
  end
end

