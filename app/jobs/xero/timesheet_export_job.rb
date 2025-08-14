# app/jobs/xero/timesheet_export_job.rb
module Xero
  class TimesheetExportJob < ApplicationJob
    queue_as :default

    def perform(timesheet_export)
      # In a real app, you'd have a robust service for token refreshing.
      # For now, we'll keep the logic here for simplicity.
      connection = XeroConnection.first
      if connection.expires_at <= Time.current + 5.minutes
        refresh_token(connection)
      end

      XeroRuby.configure do |config|
        config.access_token = connection.access_token
        config.debugging    = Rails.env.development?
      end
      api_client = XeroRuby::ApiClient.new
      payroll_api = XeroRuby::PayrollAuApi.new(api_client)
      xero_tenant_id = connection.tenant_id

      timesheet_export.update(status: "processing")
      exported_count = 0

      timesheet_export.timesheet_export_lines.group_by(&:user).each do |user, lines|
        timesheet = XeroRuby::PayrollAu::Timesheet.new(
          payroll_calendar_id: payroll_calendar_id(payroll_api, xero_tenant_id),
          employee_id: user.xero_employee_id,
          start_date: timesheet_export.pay_period_start.to_date,
          end_date: timesheet_export.pay_period_end.to_date,
          status: "DRAFT",
          timesheet_lines: lines.map do |line|
            {
              earnings_rate_id: line.earnings_rate_id,
              number_of_units: line.daily_units
            }
          end
        )

        begin
          response = payroll_api.create_timesheet(xero_tenant_id, [ timesheet ], idempotency_key: timesheet_export.idempotency_key)
          created_xero_timesheet = response.timesheets.first
          if created_xero_timesheet
            lines.each { |line| line.update(xero_timesheet_id: created_xero_timesheet.timesheet_id) }
            exported_count += 1
          end
        rescue XeroRuby::ApiError => e
          timesheet_export.update(
            status: "failed",
            error_blob: "Error for user #{user.name}: #{e.message}\n#{e.response_body}"
          )
          return # Stop processing this export
        end
      end

      timesheet_export.update(status: "completed", exported_count: exported_count)
    end

    private

    def payroll_calendar_id(payroll_api, tenant_id)
      # In a real app, you might store this on the XeroConnection
      # or an organization-level settings model.
      calendars_response = payroll_api.get_payroll_calendars(tenant_id)
      weekly_calendar = calendars_response.payroll_calendars.find { |c| c.calendar_type == "WEEKLY" }
      weekly_calendar&.payroll_calendar_id
    end

    def refresh_token(connection)
      client_id     = Rails.application.credentials.xero[:client_id]
      client_secret = Rails.application.credentials.xero[:client_secret]
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
          refresh_token: data["refresh_token"],
          expires_at:    Time.current + data["expires_in"].to_i.seconds
        )
      else
        # Handle failure, maybe by marking the connection as stale
        raise "Failed to refresh Xero token!"
      end
    end
  end
end
