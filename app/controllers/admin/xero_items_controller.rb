require "httparty"
require "ostruct"
# app/controllers/admin/xero_items_controller.rb
class Admin::XeroItemsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_connection
  before_action :set_xero_api_client

  def sync
    debug = params[:debug].present?

    begin
      tenant_id = @connection.tenant_id
      Rails.logger.info("[XeroItemsController] Begin sync; tenant=#{tenant_id} expires_at=#{@connection.expires_at}")

      # ---- Try via SDK first (with pagination) ----
      items = []
      sdk_pages = 0
      sdk_404 = false
      page = 1

      loop do
        Rails.logger.info("Calling API: AccountingApi.get_items page=#{page} ...")
        begin
          resp = @accounting_api.get_items(tenant_id, { page: page })
        rescue XeroRuby::ApiError => e
          if e.code.to_i == 404
            sdk_404 = true
            Rails.logger.warn("[XeroItemsController] SDK get_items returned 404 on page=#{page}; will try HTTP fallback")
            break
          else
            raise
          end
        end

        page_items = Array(resp&.items)
        items.concat(page_items)
        sdk_pages += 1
        break if page_items.empty? || page_items.length < 100 # Xero default page size is up to 100
        page += 1
        break if page > 50 # hard safety cap
      end

      # ---- If SDK failed with 404 or returned nothing, try raw HTTP fallback ----
      if sdk_404 || items.empty?
        Rails.logger.info("[XeroItemsController] Falling back to raw HTTP for Items ...")
        http_items, http_pages = fetch_items_via_http(@connection.access_token, tenant_id)
        items = http_items if http_items.present?
        Rails.logger.info("[XeroItemsController] HTTP fallback pages=#{http_pages} items=#{items.size}")
      else
        Rails.logger.info("[XeroItemsController] SDK collected pages=#{sdk_pages} items=#{items.size}")
      end

      # Upsert
      count = upsert_items(items)
      Rails.logger.info("[XeroItemsController] Upserted #{count} items")

      # Messaging
      if count.zero?
        message = "Sync finished: no invoice items found."
        redirect_to admin_xero_connection_path(alert: message)
      else
        message = "Synced #{count} Xero invoice item(s)."
        redirect_to admin_xero_connection_path(notice: message)
      end

    rescue XeroRuby::ApiError => e
      corr = e.respond_to?(:response_headers) ? e.response_headers&.dig("xero-correlation-id") : nil
      base = "Sync failed: #{e.message}"
      base << " Corr: #{corr}" if corr.present?
      base << " (Items endpoint returned 404 — possibly missing `accounting.items` scope or Items not enabled)" if e.code.to_i == 404
      message = base.to_s[0, 300]
      Rails.logger.error("[XeroItemsController] Sync failed ApiError(#{e.class} code=#{e.respond_to?(:code) ? e.code : 'n/a'}): #{message}")
      redirect_to admin_xero_connection_path(alert: message)

    rescue => e
      message = "Sync failed: #{e.class}: #{e.message}"
      Rails.logger.error("[XeroItemsController] #{message}\n#{e.backtrace&.first(5)&.join("\n")}")
      redirect_to admin_xero_connection_path(alert: message.to_s[0, 300])
    end
  end

  private

  # Build an AccountingApi client using the saved OAuth access token (same pattern as other Admin controllers)
  def set_xero_api_client
    XeroRuby.configure { |c| c.access_token = @connection.access_token }
    client = XeroRuby::ApiClient.new
    client.config.debugging = Rails.env.development?
    @accounting_api = XeroRuby::AccountingApi.new(client)
  end

  # Fallback: call Items endpoint directly using HTTParty, with pagination.
  def fetch_items_via_http(access_token, tenant_id)
    items = []
    pages = 0
    page = 1

    loop do
      url = "https://api.xero.com/api.xro/2.0/Items?page=#{page}"
      headers = {
        "Authorization"   => "Bearer #{access_token}",
        "Xero-Tenant-Id"   => tenant_id,
        "Accept"           => "application/json"
      }
      Rails.logger.info("[XeroItemsController] HTTP GET #{url}")
      resp = HTTParty.get(url, headers: headers)
      corr = resp.headers["xero-correlation-id"] || resp.headers["Xero-Correlation-Id"]
      Rails.logger.info("[XeroItemsController] HTTP status=#{resp.code} corr=#{corr} bytes=#{resp.body&.bytesize}")

      break if resp.code.to_i == 404 # endpoint not available
      raise "HTTP #{resp.code} error" unless resp.code.to_i == 200

      body = JSON.parse(resp.body) rescue {}
      page_items = Array(body["Items"]).map { |h| normalize_item_hash(h) }
      items.concat(page_items)
      pages += 1

      break if page_items.empty? || page_items.length < 100
      page += 1
      break if page > 50
    end

    [ items, pages ]
  end

  def normalize_item_hash(h)
    OpenStruct.new(
      item_id: h["ItemID"] || h["itemID"],
      code:    h["Code"]   || h["code"],
      name:    h["Name"]   || h["name"]
    )
  end

  # Upsert items into local table and return count processed.
  def upsert_items(items)
    return 0 if items.blank?

    items.each do |item|
      item_id = item.respond_to?(:item_id) ? item.item_id : (item["ItemID"] || item[:ItemID])
      code    = item.respond_to?(:code)    ? item.code    : (item["Code"]   || item[:Code])
      name    = item.respond_to?(:name)    ? item.name    : (item["Name"]   || item[:Name])

      XeroItem.upsert(
        {
          xero_item_id: item_id,
          code:         code,
          name:         name,
          created_at:   Time.current,
          updated_at:   Time.current
        },
        unique_by: :index_xero_items_on_xero_item_id
      )
    end

    items.size
  end

  def set_connection
    @connection = XeroConnection.first!
  end
end
