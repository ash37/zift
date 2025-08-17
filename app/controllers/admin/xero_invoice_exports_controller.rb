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
    # Dates (defaults to Wed–Tue week like your logs show)
    @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : Date.today.beginning_of_week(:wednesday)
    @end_date   = params[:end_date].present?   ? Date.parse(params[:end_date])   : (@start_date + 6.days)

    tz   = ActiveSupport::TimeZone["Australia/Brisbane"]
    from = tz.parse(@start_date.to_s).beginning_of_day
    to   = tz.parse(@end_date.to_s).end_of_day

    # EXACTLY the same scope your logs show (approved + area present)
    @approved_timesheets = Timesheet
      .where(status: 1) # approved
      .where(clock_in_at: from..to)
      .joins(:shift)
      .where.not(shifts: { area_id: nil })
      .includes(shift: [ :location, :area, :user ])
      .order("shifts.start_time ASC")

    # If the rest of your controller uses another var, make it point to the same list
    @timesheets ||= @approved_timesheets
  end

  def create
    # Parse dates (used only to select timesheets and to round-trip back to the page)
    start_date = (Date.parse(params[:start_date]) rescue nil) || Date.today.beginning_of_week(:wednesday)
    end_date   = (Date.parse(params[:end_date])   rescue nil) || (start_date + 6.days)

    tz   = ActiveSupport::TimeZone["Australia/Brisbane"]
    from = tz.parse(start_date.to_s).beginning_of_day
    to   = tz.parse(end_date.to_s).end_of_day
    range = from..to

    selected_ids = Array(params[:timesheet_ids]).reject(&:blank?).map(&:to_i)

    timesheets =
      if selected_ids.present?
        Rails.logger.info("[XeroInvoiceExports] Using #{selected_ids.size} explicitly selected timesheets")
        Timesheet.includes(shift: [ :location, :area, :user ]).where(id: selected_ids)
      else
        Rails.logger.info("[XeroInvoiceExports] No timesheet_ids selected; using all eligible timesheets in range #{start_date}..#{end_date}")
        Timesheet
          .where(status: 1) # approved
          .where(clock_in_at: range)
          .joins(:shift)
          .where.not(shifts: { area_id: nil })
          .includes(shift: [ :location, :area, :user ])
          .order("shifts.start_time ASC")
      end

    if timesheets.blank?
      redirect_to new_admin_xero_invoice_export_path(start_date: start_date, end_date: end_date),
                  alert: "No eligible timesheets found to export."
      return
    end

    # NOTE: InvoiceExport does NOT have start_date/end_date columns.
    export = InvoiceExport.create!(
      status: "queued",
      idempotency_key: SecureRandom.uuid,
      total_count: timesheets.size
    )

    # Build one InvoiceExportLine per timesheet (keeps your existing “hours worked” behaviour intact).
    timesheets.find_each do |ts|
      shift    = ts.shift
      location = shift&.location
      area     = shift&.area
      next if area.nil? || location.nil?

      work_day = (ts.clock_in_at || ts.created_at).in_time_zone("Australia/Brisbane").to_date
      hours    = (ts.duration.to_f / 3600.0).round(2)
      rate     = ts.respond_to?(:cost) ? ts.cost : nil
      employee = shift.user&.name

      # Preserve your existing description intent for hours-worked lines
      desc = "#{area.name} - #{employee} - #{work_day.strftime('%d %b %Y')} - #{hours}h"
      desc += " @ $#{rate}" if rate.present?

      InvoiceExportLine.create!(
        invoice_export: export,
        location: location,
        area: area,
        timesheet: ts,
        description: desc
      )
    end

    # Run the export job now; it will add the Travel line items (separate line with quantity = ts.travel)
    Xero::InvoiceExportJob.perform_now(export)

    redirect_to new_admin_xero_invoice_export_path(start_date: start_date, end_date: end_date),
                notice: "Exported #{export.invoice_export_lines.count} line(s) to Xero."
  end

  private

  def set_xero_api_client
    connection = XeroConnection.first
    unless connection
      redirect_to admin_xero_connection_path, alert: "You must be connected to Xero to export invoices."
      return
    end

    Rails.logger.info("[XeroInvoiceExports] Pre-refresh token_expires_at=#{connection.expires_at&.iso8601} tenant_id=#{connection.tenant_id || 'nil'}")

    if connection.expires_at && connection.expires_at <= Time.current + 5.minutes
      refreshed = refresh_token(connection)
      unless refreshed
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
        refresh_token: data["refresh_token"] || connection.refresh_token,
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
