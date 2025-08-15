# app/jobs/xero/timesheet_export_job.rb
module Xero
  class TimesheetExportJob < ApplicationJob
    queue_as :default

    def perform(timesheet_export)
      connection = XeroConnection.first
      if connection.expires_at <= Time.current + 5.minutes
        refresh_token(connection)
      end

      xero_tenant_id = connection.tenant_id
      access_token = connection.access_token

      timesheet_export.update(status: "processing")
      exported_count = 0

      timesheet_export.timesheet_export_lines.group_by(&:user).each do |user, lines|
        timesheet_payload = {
          "EmployeeID" => user.xero_employee_id,
          "StartDate" => timesheet_export.pay_period_start.to_date.iso8601,
          "EndDate" => timesheet_export.pay_period_end.to_date.iso8601,
          "Status" => "DRAFT",
          "TimesheetLines" => lines.map do |line|
            {
              "EarningsRateID" => line.earnings_rate_id,
              "NumberOfUnits" => line.daily_units
            }
          end
        }

        begin
          response = HTTParty.post(
            "https://api.xero.com/payroll.xro/1.0/Timesheets",
            headers: {
              "Authorization"  => "Bearer #{access_token}",
              "Xero-Tenant-Id" => xero_tenant_id,
              "Content-Type"   => "application/json",
              "Accept"         => "application/json",
              # **THE FIX IS HERE**: The idempotency key is now correctly sent as a header.
              "Idempotency-Key" => timesheet_export.idempotency_key
            },
            # **THE FIX IS HERE**: The body is now a JSON array, as required by the API.
            body: [ timesheet_payload ].to_json
          )

          if response.success?
            created_xero_timesheet = response.parsed_response.dig("Timesheets", 0)
            if created_xero_timesheet
              lines.each { |line| line.update(xero_timesheet_id: created_xero_timesheet["TimesheetID"]) }
              exported_count += 1
            end
          else
            raise "Xero API Error: #{response.code} - #{response.body}"
          end

        rescue => e
          timesheet_export.update(
            status: "failed",
            error_blob: "Error for user #{user.name}: #{e.message}"
          )
          return
        end
      end

      timesheet_export.update(status: "completed", exported_count: exported_count)
    end

    private

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
        raise "Failed to refresh Xero token!"
      end
    end
  end
end
