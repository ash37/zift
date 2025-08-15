class InvoiceExport < ApplicationRecord
  has_many :invoice_export_lines, dependent: :destroy

  validates :idempotency_key, presence: true, uniqueness: true
  validates :status, presence: true
end
