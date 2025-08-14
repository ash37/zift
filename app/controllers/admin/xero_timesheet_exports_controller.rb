class Admin::XeroTimesheetExportsController < ApplicationController
  before_action :authenticate_user!
  # before_action :require_admin!
  before_action :set_xero_api_client, only: [ :new, :create ]

  def new
    fetch_payroll_calendar
    return if performed?

    if @payroll_calendar
      @pay_period_start = @payroll_calendar.start_date.to_date
      @pay_period_end   = @payroll_calendar.end_date.to_date
    else
      week_start = Date.current.beginning_of_week(:wednesday)
      @pay_period_start = week_start
      @pay_period_end   = week_start + 6.days
    end

    # Allow manual override via query params (from the date-range picker)
    default_start = @pay_period_start
    default_end   = @pay_period_end

    if params[:start_date].present? || params[:end_date].present?
      begin
        @pay_period_start = params[:start_date].present? ? params[:start_date].to_date : @pay_period_start
        @pay_period_end   = params[:end_date].present?   ? params[:end_date].to_date   : @pay_period_end
      rescue ArgumentError
        @pay_period_start = default_start
        @pay_period_end   = default_end
        flash.now[:warning] = "Invalid date parameters provided. Showing detected pay period instead."
      end
    end

    @user_hours = User.where.not(xero_employee_id: nil).map do |user|
      total_hours = user.timesheets
                        .where(status: "approved", clock_in_at: @pay_period_start..@pay_period_end)
                        .sum { |t| (t.clock_out_at - t.clock_in_at) / 3600.0 }
      { user: user, total_hours: total_hours }
    end.reject { |data| data[:total_hours].zero? }
  end

  def create
    # We will implement the background job logic here in the next step
    redirect_to admin_xero_connection_path, notice: "Timesheet export has been successfully queued."
  end

  private

  def set_xero_api_client
    connection = XeroConnection.first
    unless connection
      redirect_to admin_xero_connection_path, alert: "You must be connected to Xero to export timesheets."
      return
    end

    # This is a simplified version of the refresh logic from the other controller
    if connection.expires_at <= Time.current + 5.minutes
      # Handle token refresh (you would extract this into a service in a real app)
    end

    XeroRuby.configure { |c| c.access_token = connection.access_token }
    @xero_client = XeroRuby::ApiClient.new
  end

  def fetch_payroll_calendar
    xero_tenant_id = XeroConnection.first.tenant_id
    stored_scopes = XeroConnection.first&.scopes
    Rails.logger.info("Xero: Stored scopes => #{stored_scopes.inspect}")
    api_instance = XeroRuby::PayrollAuApi.new(@xero_client)

    begin
      Rails.logger.info("Xero: Calling PayrollAuApi.get_payroll_calendars ... tenant=#{xero_tenant_id}")
      # GET /PayrollCalendars (AU Payroll API)
      calendars_response = api_instance.get_payroll_calendars(xero_tenant_id)
      calendars = calendars_response&.payroll_calendars || []
      Rails.logger.info("Xero: PayrollCalendars returned count=#{calendars.size} ids=#{calendars.map(&:payroll_calendar_id).join(',')}")
    rescue XeroRuby::ApiError => e
      # Capture as much context as possible for support/debugging
      code = (e.respond_to?(:code) ? e.code : nil)
      headers = (e.respond_to?(:response_headers) ? e.response_headers : {}) || {}
      corr = headers["xero-correlation-id"] || headers["Xero-Correlation-Id"]
      body_preview = (e.respond_to?(:response_body) && e.response_body) ? e.response_body.to_s[0, 500] : ""
      Rails.logger.warn("Xero: get_payroll_calendars failed code=#{code} corr=#{corr} headers=#{headers.inspect} body_preview=#{body_preview}")

      if code.to_i == 404
        begin
          Rails.logger.info("Xero: Probe PayrollAuApi.get_settings to check payroll.settings scope/permission ...")
          settings = api_instance.get_settings(xero_tenant_id)
          Rails.logger.info("Xero: get_settings OK — payroll.settings scope present. Settings keys=#{settings.to_h.keys}")
          # Do not redirect on 404 calendars if settings works; allow fallback dates
          @payroll_calendar = nil
          Rails.logger.info("Xero: get_payroll_calendars 404 but settings OK — proceeding with fallback week in controller#new")
          return
        rescue XeroRuby::ApiError => se
          s_code = (se.respond_to?(:code) ? se.code : nil)
          s_headers = (se.respond_to?(:response_headers) ? se.response_headers : {}) || {}
          s_corr = s_headers["xero-correlation-id"] || s_headers["Xero-Correlation-Id"]
          Rails.logger.warn("Xero: get_settings probe failed code=#{s_code} corr=#{s_corr}")
          if [ 401, 403 ].include?(s_code.to_i)
            redirect_to admin_xero_connection_path, alert: "Xero connection may be missing the required payroll.settings scope or user lacks Payroll permissions. Please reconnect and include: offline_access accounting.settings payroll.employees payroll.employees.read payroll.settings. Correlation ID: #{corr}" and return
          else
            # For other errors, still fall back to rendering with a nil calendar
            @payroll_calendar = nil
            Rails.logger.info("Xero: get_payroll_calendars 404 and settings probe not 401/403 (code=#{s_code}) — proceeding with fallback week")
            return
          end
        end
      end

      redirect_to admin_xero_connection_path, alert: "Error fetching payroll calendars from Xero (#{code}). Correlation ID: #{corr}. #{e.message}" and return
    end

    # Prefer a WEEKLY calendar, otherwise fall back to the first available
    @payroll_calendar = calendars.find { |c| c.calendar_type == "WEEKLY" } || calendars.first

    unless @payroll_calendar
      redirect_to admin_xero_connection_path, alert: "No payroll calendars returned by Xero. Please add one in Xero Payroll (Settings → Payroll → Pay calendars) and retry." and return
    end
  end
end
