require "ostruct"
class Admin::XeroTimesheetExportsController < ApplicationController
  before_action :authenticate_user!
  # before_action :require_admin!
  before_action :set_xero_api_client, only: [ :new, :create ]

  def index
    redirect_to new_admin_xero_timesheet_export_path
  end

  def new
    base_date = params[:start_date] ? Date.parse(params[:start_date]) : Time.zone.today
    @pay_period_start = base_date.beginning_of_week(:wednesday)
    @pay_period_end   = @pay_period_start + 6.days

    cal_objs = Array(xero_service.payroll_calendars).map do |cal|
      OpenStruct.new(
        id:            try_attr(cal, :payroll_calendar_id) || try_attr(cal, "PayrollCalendarID"),
        start_date:    to_time_or_nil(try_attr(cal, :start_date) || try_attr(cal, "StartDate"))
      )
    end
    @payroll_calendar = cal_objs.find { |c| c.start_date&.to_date == @pay_period_start }

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
      status: "pending"
    )

    shift_types_by_name = ShiftType.all.index_by { |st| st.name.to_s.downcase }
    timesheets = Timesheet.includes(shift: [ :user, :roster ])
                          .where(status: Timesheet::STATUSES[:approved])
                          .where(clock_in_at: pay_period_start.beginning_of_day..pay_period_end.end_of_day)
                          .where.not(users: { xero_employee_id: nil })

    number_of_days = (pay_period_end - pay_period_start).to_i + 1
    aggregated_hours = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = Array.new(number_of_days, 0.0) } }

    timesheets.each do |ts|
      user = ts.user
      current_time = ts.clock_in_at
      while current_time < ts.clock_out_at
        rate_name = ts.shift.determine_rate_name_for_time(current_time)
        shift_type = shift_types_by_name[rate_name.to_s.downcase]
        earnings_rate_id = shift_type&.xero_earnings_rate_id

        if earnings_rate_id.present?
          day_index = (current_time.to_date - pay_period_start).to_i
          if day_index >= 0 && day_index < number_of_days
            aggregated_hours[user][earnings_rate_id][day_index] += 1 / 60.0
          end
        end
        current_time += 1.minute
      end

      # Add travel units (captured at clock-off) into the daily aggregation as a separate earnings rate line
      if ts.respond_to?(:travel)
        travel_units = ts.travel.to_f
        if travel_units.positive?
          travel_shift_type = shift_types_by_name["travel"]
          travel_rate_id = travel_shift_type&.xero_earnings_rate_id

          if travel_rate_id.present?
            # Attribute travel to the clock-out day (when the user enters it)
            travel_day_index = (ts.clock_out_at.to_date - pay_period_start).to_i
            if travel_day_index >= 0 && travel_day_index < number_of_days
              aggregated_hours[user][travel_rate_id][travel_day_index] += travel_units
            end
          end
        end
      end
    end

    total_lines = 0
    aggregated_hours.each do |user, rates|
      rates.each do |earnings_rate_id, daily_units|
        total_lines += 1
        rounded_units = daily_units.map { |hours| hours.round(4) }
        timesheet_export.timesheet_export_lines.create!(
          user: user,
          earnings_rate_id: earnings_rate_id,
          daily_units: rounded_units
        )
      end
    end

    timesheet_export.update!(total_count: total_lines)

    # **THE FIX IS HERE**: The unnecessary calendar ID is removed from the job call.
    Xero::TimesheetExportJob.perform_later(timesheet_export)

    redirect_to admin_xero_connection_path, notice: "Timesheet export ##{timesheet_export.id} has been queued with #{total_lines} lines."
  end

  private

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
    if (m = s.match(%r{\/Date\((\d+)(?:[+-]\d+)?\)\/}))
      millis = m[1].to_i
      return Time.zone.at(millis / 1000)
    end
    Time.zone.parse(s) rescue nil
  end

  def xero_service
    tenant_id = XeroConnection.first&.tenant_id
    OpenStruct.new(payroll_calendars: fetch_payroll_calendar(tenant_id))
  end

  def set_xero_api_client
    connection = XeroConnection.first
    unless connection
      redirect_to admin_xero_connection_path, alert: "You must be connected to Xero to export timesheets."
      return
    end
    if connection.expires_at <= Time.current + 5.minutes
      # Handle token refresh
    end
    XeroRuby.configure { |c| c.access_token = connection.access_token }
    @xero_client = XeroRuby::ApiClient.new
    @payroll_api = XeroRuby::PayrollAuApi.new(@xero_client)
  end

  def fetch_payroll_calendar(tenant_id)
    api = @payroll_api
    begin
      resp = api.get_payroll_calendars(tenant_id)
      return Array(resp&.payroll_calendars) if resp&.payroll_calendars.present?
    rescue XeroRuby::ApiError => e
      if e.code.to_i == 404
        url = "https://api.xero.com/payroll.xro/1.0/PayrollCalendars"
        access_token = XeroConnection.first.access_token
        raw = HTTParty.get(url, headers: { "Authorization" => "Bearer #{access_token}", "Xero-Tenant-Id" => tenant_id, "Accept" => "application/json" })
        if raw.code.to_i == 200 && raw.body.present?
          return Array(JSON.parse(raw.body)["PayrollCalendars"]) rescue []
        end
      end
    end
    []
  end

  def fetch_user_hours(pay_period_start, pay_period_end)
    User.where.not(xero_employee_id: nil).map do |user|
      total_hours = user.timesheets
                        .where(status: Timesheet::STATUSES[:approved])
                        .where(clock_in_at: pay_period_start.beginning_of_day..pay_period_end.end_of_day)
                        .sum { |t| (t.clock_out_at - t.clock_in_at) / 3600.0 }
      { user: user, total_hours: total_hours }
    end.reject { |data| data[:total_hours].zero? }
  end
end
