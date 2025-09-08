require 'digest'
class Agreement < ApplicationRecord
  DOCUMENT_TYPES = %w[employment service].freeze

  validates :document_type, presence: true, inclusion: { in: DOCUMENT_TYPES }
  validates :version, numericality: { only_integer: true, greater_than: 0 }
  validates :title, :body, presence: true

  scope :active, -> { where(active: true) }
  scope :for_type, ->(type) { where(document_type: type) }

  def self.current_for(type)
    active.for_type(type).order(version: :desc).first
  end

  def content_hash
    Digest::SHA256.hexdigest([document_type, version, title, body].join("\n---\n"))
  end
end
