# app/controllers/admin/xero_item_mappings_controller.rb
class Admin::XeroItemMappingsController < ApplicationController
  before_action :set_connection

  def show
    @areas = Area.includes(:location).order(:name)
    @items = fetch_items # [{code:, name:}, ...] from local cache table
  end

  def update
    # params: { mappings: { "<area_id>" => "<xero_item_code>", ... } }
    (params[:mappings] || {}).each do |area_id, code|
      Area.where(id: area_id).update_all(xero_item_code: code.presence)
    end
    redirect_to admin_xero_item_mappings_path, notice: "Mappings saved."
  end

  def sync
    # Force pull from Xero and upsert into local cache table
    synced_count = sync_items_from_xero
    redirect_to admin_xero_item_mappings_path, notice: "Synced #{synced_count} items from Xero."
  end

  private

  def set_connection
    @connection = XeroConnection.first or raise ActiveRecord::RecordNotFound
  end

  # Return items for the view from local cache unless forcing a refresh
  def fetch_items(force: false)
    if force
      sync_items_from_xero
    end

    XeroItem.order(:code).pluck(:code, :name).map { |code, name| { code: code, name: name } }
  end

  def sync_items_from_xero
    XeroRuby.configure { |c| c.access_token = @connection.access_token }
    api_client     = XeroRuby::ApiClient.new
    accounting_api = XeroRuby::AccountingApi.new(api_client)

    resp = accounting_api.get_items(@connection.tenant_id)
    items = Array(resp.items)
    XeroItem.bulk_upsert_from_xero!(items)
    items.size
  rescue XeroRuby::ApiError => e
    Rails.logger.error("[XeroItemMappings] get_items error: #{e.response_body}")
    0
  end
end
