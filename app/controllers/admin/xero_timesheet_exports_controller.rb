require "ostruct"
class Admin::XeroTimesheetExportsController < ApplicationController
  before_action :authenticate_user!
  # before_action :require_admin!
  before_action :set_xero_api_client, only: [ :new, :create ]

  def index
    redirect_to new_admin_xero_timesheet_export_path
  end

  def new
    cal_objs = Array(xero_service.payroll_calendars).map do |cal|
      # Be tolerant to different shapes (SDK, OpenStruct, Hash)
      OpenStruct.new(
        id:            try_attr(cal, :payroll_calendar_id) || try_attr(cal, :calendar_id),
        calendar_type: try_attr(cal, :calendar_type).to_s,             # "WEEKLY", etc
        start_date:    to_time_or_nil(try_attr(cal, :start_date)),
        end_date:      to_time_or_nil(try_attr(cal, :end_date))
      )
    end

    @payroll_calendar =
      cal_objs.find { |c| c.calendar_type.to_s.upcase == "WEEKLY" } || cal_objs.first

    if @payroll_calendar&.start_date
      s = @payroll_calendar.start_date.to_date
      e = @payroll_calendar.end_date ? @payroll_calendar.end_date.to_date : (s + 6) # 7-day window if end missing
      @pay_period_start = s
      @pay_period_end   = e
    else
      today = Date.current
      @pay_period_start = today - ((today.wday - 3) % 7) # Wednesday
      @pay_period_end   = @pay_period_start + 6          # Tuesday
    end

    @user_hours = fetch_user_hours(@pay_period_start, @pay_period_end)
  end

  def create
    pay_period_start = Date.parse(params[:pay_period_start])
    pay_period_end = Date.parse(params[:pay_period_end])
    idempotency_key = SecureRandom.uuid

    timesheet_export = TimesheetExport.create!(
      idempotency_key: idempotency_key,
      pay_period_start: pay_period_start,
      pay_period_end: pay_period_end,
      status: "pending" # Start as pending, the job will update it
    )

    # Pre-fetch shift types to avoid N+1 queries in the loop
    shift_types = ShiftType.all.index_by(&:name)

    # 1. Gather approved timesheets for linked users
    timesheets = Timesheet.includes(shift: [ :user, :roster ])
                          .where(status: Timesheet::STATUSES[:approved])
                          .where(clock_in_at: pay_period_start.beginning_of_day..pay_period_end.end_of_day)
                          .where.not(users: { xero_employee_id: nil })

    # Hash to aggregate hours per user per earnings rate for the whole period
    # { user1 => { earnings_rate_id_1 => [day1_hrs, day2_hrs, ...], ... }, ... }
    number_of_days = (pay_period_end - pay_period_start).to_i + 1
    aggregated_hours = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = Array.new(number_of_days, 0.0) } }

    timesheets.each do |ts|
      current_time = ts.clock_in_at
      while current_time < ts.clock_out_at
        rate_name = ts.shift.determine_rate_name_for_time(current_time)
        shift_type = shift_types[rate_name]
        earnings_rate_id = shift_type&.xero_earnings_rate_id

        if earnings_rate_id.present?
          day_index = (current_time.to_date - pay_period_start).to_i
          if day_index >= 0 && day_index < number_of_days
            aggregated_hours[ts.user][earnings_rate_id][day_index] += 1 / 60.0 # add 1 minute of hours
          end
        end
        current_time += 1.minute
      end
    end

    # 4. Create TimesheetExportLine records from the aggregated data
    total_lines = 0
    aggregated_hours.each do |user, rates|
      rates.each do |earnings_rate_id, daily_units|
        total_lines += 1
        # Round each daily unit to 4 decimal places
        rounded_units = daily_units.map { |hours| hours.round(4) }

        timesheet_export.timesheet_export_lines.create!(
          user: user,
          earnings_rate_id: earnings_rate_id,
          daily_units: rounded_units
        )
      end
    end

    timesheet_export.update!(total_count: total_lines)

    # Enqueue the job to send the data to Xero
    Xero::TimesheetExportJob.perform_later(timesheet_export)

    redirect_to admin_xero_connection_path, notice: "Timesheet export ##{timesheet_export.id} has been queued with #{total_lines} lines."
  end

  private

  # Safe attribute access for SDK objects, OpenStructs, or Hashes
  def try_attr(obj, key)
    return obj.public_send(key) if obj.respond_to?(key)
    return obj[key]             if obj.is_a?(Hash) && obj.key?(key)
    return obj[key.to_s]        if obj.is_a?(Hash) && obj.key?(key.to_s)
    nil
  end

  def to_time_or_nil(val)
    return nil if val.blank?
    return val.to_time if val.respond_to?(:to_time)

    s = val.to_s
    if (m = s.match(%r{\/Date\((\d+)(?:[+-]\d+)?\)\/})) # Xero /Date(…)/ millis
      millis = m[1].to_i
      return Time.zone.at(millis / 1000)
    end

    Time.zone.parse(s) rescue nil
  end

  # Adapter so the new action can call xero_service.payroll_calendars
  def xero_service
    tenant_id = XeroConnection.first&.tenant_id
    OpenStruct.new(payroll_calendars: fetch_payroll_calendar(tenant_id))
  end

  # Accepts either an SDK calendar object or a raw AU v1 Hash and returns an OpenStruct:
  #   id, calendar_type ("WEEKLY"/...), start_date (Time), end_date (Time or nil)
  def normalize_calendar(cal)
    # SDK object path
    if cal.respond_to?(:calendar_type) || cal.respond_to?(:start_date)
      return OpenStruct.new(
        id:            (cal.respond_to?(:payroll_calendar_id) ? cal.payroll_calendar_id : (cal.respond_to?(:calendar_id) ? cal.calendar_id : nil)),
        calendar_type: cal.respond_to?(:calendar_type) ? cal.calendar_type.to_s : nil,
        start_date:    parse_xero_date(cal.respond_to?(:start_date) ? cal.start_date : nil),
        end_date:      parse_xero_date(cal.respond_to?(:end_date)   ? cal.end_date   : nil)
      )
    end

    # Raw Hash path (AU Payroll v1)
    h = cal.is_a?(Hash) ? cal : cal.to_h

    # Raw AU doesn’t usually include an explicit end date; we can infer a 7-day window later
    OpenStruct.new(
      id:            h["PayrollCalendarID"] || h[:PayrollCalendarID] || h[:payroll_calendar_id] || h["payroll_calendar_id"],
      calendar_type: (h["CalendarType"] || h[:CalendarType] || h[:calendar_type] || h["calendar_type"]).to_s,
      start_date:    parse_xero_date(h["StartDate"] || h[:StartDate] || h[:start_date] || h["start_date"]),
      end_date:      parse_xero_date(h["EndDate"]   || h[:EndDate]   || h[:end_date]   || h["end_date"]) # may be nil in AU
    )
  end

  # Handles both SDK Time/Date values and Xero JSON date strings like "/Date(1755648000000+0000)/"
  def parse_xero_date(val)
    return nil if val.blank?
    return val.to_time if val.respond_to?(:to_time)

    s = val.to_s
    if (m = s.match(%r{\/Date\((\d+)(?:[+-]\d+)?\)\/}))
      millis = m[1].to_i
      return Time.zone.at(millis / 1000)
    end

    Time.zone.parse(s) rescue nil
  end

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
    @payroll_api = XeroRuby::PayrollAuApi.new(@xero_client)
  end

  # in Admin::XeroTimesheetExportsController
  def fetch_payroll_calendar(tenant_id)
    api = @payroll_api # XeroRuby::PayrollAuApi
    Rails.logger.info("Calling API: #{api.class}.get_payroll_calendars ...")

    begin
      resp = api.get_payroll_calendars(tenant_id)
      cals = Array(resp&.payroll_calendars)
      return cals if cals.any?
    rescue XeroRuby::ApiError => e
      code    = e.respond_to?(:code) ? e.code : nil
      headers = (e.respond_to?(:response_headers) ? e.response_headers : {}) || {}
      corr    = headers["xero-correlation-id"] || headers["Xero-Correlation-Id"]
      Rails.logger.warn("Xero: get_payroll_calendars failed code=#{code} corr=#{corr} headers=#{headers.inspect}")

      if code.to_i == 404
        # RAW fallback for AU v1
        url = "https://api.xero.com/payroll.xro/1.0/PayrollCalendars"
        access_token = XeroConnection.first.access_token

        raw = HTTParty.get(
          url,
          headers: {
            "Authorization"  => "Bearer #{access_token}",
            "Xero-Tenant-Id" => tenant_id,
            "Accept"         => "application/json"
          }
        )
        Rails.logger.info("Raw AU PayrollCalendars -> status=#{raw.code} bytes=#{raw.body.to_s.bytesize}")

        if raw.code.to_i == 200 && raw.body.present?
          begin
            parsed = JSON.parse(raw.body)
            return Array(parsed["PayrollCalendars"] || parsed["payrollCalendars"])
          rescue JSON::ParserError
            Rails.logger.warn("Raw AU PayrollCalendars response invalid JSON")
          end
        end
      elsif [ 401, 403 ].include?(code.to_i)
        redirect_to(
          admin_xero_connection_path,
          alert: "Xero payroll calendars not accessible (#{code}). Please reconnect Xero with scopes: offline_access accounting.settings.read payroll.employees payroll.employees.read payroll.settings payroll.timesheets."
        ) and return
      end
    end

    [] # fallback to “no calendars”
  end

  def fetch_user_hours(pay_period_start, pay_period_end)
    User.where.not(xero_employee_id: nil).map do |user|
      total_hours = Timesheet.where(user_id: user.id)
                             .unapproved
                             .where(clock_in_at: pay_period_start..pay_period_end)
                             .sum { |t| (t.clock_out_at - t.clock_in_at) / 3600.0 }
      { user: user, total_hours: total_hours }
    end.reject { |data| data[:total_hours].zero? }
  end
end
