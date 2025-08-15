class InvoiceExportLine < ApplicationRecord
  belongs_to :invoice_export
  belongs_to :location
  belongs_to :area
  belongs_to :timesheet
end
