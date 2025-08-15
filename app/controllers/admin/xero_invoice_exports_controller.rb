require "ostruct"

class Admin::XeroInvoiceExportsController < ApplicationController
  before_action :authenticate_user!
  # before_action :require_admin!
  before_action :set_xero_api_client, only: [ :new, :create ]

  # Parse a date string or return nil
  def parse_date(str)
    Date.parse(str) rescue nil
  end

  def new
    @start_date = parse_date(params[:start_date]) || Date.today.beginning_of_week(:wednesday)
    @end_date   = parse_date(params[:end_date])   || (@start_date + 6.days)

    timesheets = Timesheet.eager_load(shift: [ :location, :area, :user ])
                          .where(status: Timesheet::STATUSES[:approved])
                          .where(clock_in_at: @start_date.beginning_of_day..@end_date.end_of_day)
                          .where.not(shifts: { area_id: nil })
                          .order("shifts.start_time ASC")

    @invoice_groups = timesheets.group_by { |t| t.shift.location }.map do |location, location_timesheets|
      OpenStruct.new(location: location, timesheets: location_timesheets)
    end
  end

  def create
    start_date = parse_date(params[:start_date]) || Date.today.beginning_of_week(:wednesday)
    end_date   = parse_date(params[:end_date])   || (start_date + 6.days)
    idempotency_key = SecureRandom.uuid

    invoice_export = InvoiceExport.create!(
      idempotency_key: idempotency_key,
      status: "pending"
    )

    timesheets = Timesheet.includes(shift: [ :location, :area ])
                          .where(status: Timesheet::STATUSES[:approved])
                          .where(clock_in_at: start_date.beginning_of_day..end_date.end_of_day)
                          .where.not(shift: { area_id: nil })

    Rails.logger.info("[XeroInvoiceExports] Building export: timesheets=#{timesheets.size} start=#{start_date} end=#{end_date}")

    timesheets.each do |ts|
      invoice_export.invoice_export_lines.create!(
        timesheet: ts,
        location: ts.shift.location,
        area: ts.shift.area,
        description: "One Staff on #{ts.clock_in_at.strftime('%a %d %b %Y')} from #{ts.clock_in_at.strftime('%-l:%M%P')} - #{ts.clock_out_at.strftime('%-l:%M%P')}"
      )
    end

    total_invoices = timesheets.map { |ts| ts.shift.location_id }.uniq.count
    invoice_export.update!(total_count: total_invoices)

    Rails.logger.info("[XeroInvoiceExports] Enqueued export ##{invoice_export.id} total_invoices=#{total_invoices}")

    Xero::InvoiceExportJob.perform_later(invoice_export)

    redirect_to admin_xero_connection_path, notice: "Invoice export ##{invoice_export.id} has been queued with #{total_invoices} invoices."
  end

  private

  def set_xero_api_client
    connection = XeroConnection.first
    unless connection
      redirect_to admin_xero_connection_path, alert: "You must be connected to Xero to export invoices."
      return
    end

    # Debug: token timing and tenant visibility
    Rails.logger.info("[XeroInvoiceExports] Pre-refresh token_expires_at=#{connection.expires_at&.iso8601} tenant_id=#{connection.tenant_id || 'nil'}")

    # Proactively refresh the token (with halt on failure)
    if connection.expires_at && connection.expires_at <= Time.current + 5.minutes
      refreshed = refresh_token(connection)
      unless refreshed
        # refresh_token already redirected; stop filter chain
        Rails.logger.warn("[XeroInvoiceExports] Token refresh failed; halting request")
        return
      end
      connection.reload
      Rails.logger.info("[XeroInvoiceExports] Post-refresh token_expires_at=#{connection.expires_at&.iso8601}")
    end

    XeroRuby.configure { |c| c.access_token = connection.access_token }
    @xero_client = XeroRuby::ApiClient.new
    @accounting_api = XeroRuby::AccountingApi.new(@xero_client)
  end

  def refresh_token(connection)
    client_id     = Rails.application.credentials.dig(:xero, :client_id)
    client_secret = Rails.application.credentials.dig(:xero, :client_secret)

    unless client_id.present? && client_secret.present?
      Rails.logger.error("[XeroInvoiceExports] Missing Xero OAuth credentials; cannot refresh token")
      redirect_to admin_xero_connection_path, alert: "Missing Xero OAuth credentials. Please reconnect."
      return false
    end

    response = HTTParty.post(
      "https://identity.xero.com/connect/token",
      headers: { "Content-Type" => "application/x-www-form-urlencoded" },
      body:    { grant_type: "refresh_token", refresh_token: connection.refresh_token },
      basic_auth: { username: client_id, password: client_secret }
    )

    if response.success?
      data = response.parsed_response
      connection.update!(
        access_token:  data["access_token"],
        refresh_token: data["refresh_token"] || connection.refresh_token, # Xero sometimes rotates
        expires_at:    Time.current + data["expires_in"].to_i.seconds
      )
      Rails.logger.info("[XeroInvoiceExports] Token refreshed successfully; new expiry=#{connection.expires_at&.iso8601}")
      true
    else
      Rails.logger.error("[XeroInvoiceExports] Token refresh failed status=#{response.code} body=#{response.body}")
      redirect_to admin_xero_connection_path, alert: "Failed to refresh Xero token (#{response.code}). Please try reconnecting."
      false
    end
  end
end
