namespace :xero do
  desc "Run the latest pending Xero timesheet export job"
  task export_latest_timesheet: :environment do
    export = TimesheetExport.where(status: "pending").order(created_at: :desc).first
    if export
      puts "Found pending export ##{export.id}, created at #{export.created_at}."
      puts "Running job now..."
      Xero::TimesheetExportJob.perform_now(export)
      puts "Job finished. Final status: #{export.reload.status}"
    else
      puts "No pending timesheet exports found."
    end
  end
end
