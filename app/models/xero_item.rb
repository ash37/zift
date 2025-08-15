# app/models/xero_item.rb
class XeroItem < ApplicationRecord
  validates :code, presence: true, uniqueness: true
  validates :xero_item_id, uniqueness: true, allow_nil: true

  # Upsert a single item payload from Xero
  def self.upsert_from_xero!(x_item)
    attrs = {
      code:         x_item.code,
      name:         x_item.name,
      xero_item_id: (x_item.try(:item_id) || x_item.try(:id))
    }.compact

    rec = find_or_initialize_by(code: attrs[:code])
    rec.assign_attributes(attrs)
    rec.save! if rec.changed?
    rec
  end

  # Bulk upsert from an array of Xero SDK items
  def self.bulk_upsert_from_xero!(items)
    Array(items).each { |xi| upsert_from_xero!(xi) }
  end

  def self.sync_from_xero!(connection)
    api_client     = XeroRuby::ApiClient.new
    accounting_api = XeroRuby::AccountingApi.new(api_client)

    # connection.access_token is expected to be the raw OAuth2 access token string
    api_client.set_oauth2_token(connection.access_token)

    total = 0
    page  = 1

    loop do
      Rails.logger.info("[XeroItem] Fetching items page=#{page} ...")
      resp   = accounting_api.get_items(connection.tenant_id, page: page)
      items  = Array(resp.items)
      break if items.empty?

      bulk_upsert_from_xero!(items)
      total += items.size
      page  += 1
    end

    total
  rescue XeroRuby::ApiError => e
    corr = (e.response_headers && e.response_headers["xero-correlation-id"])
    Rails.logger.error("[XeroItem] sync_from_xero! ApiError status=#{e.code} corr=#{corr} body=#{e.response_body.presence || '(empty)'}")
    raise
  end
end
