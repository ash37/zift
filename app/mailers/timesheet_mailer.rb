class TimesheetMailer < ApplicationMailer
  def shift_feedback
    @timesheet = params[:timesheet]
    @location  = @timesheet.shift&.location
    @user      = @timesheet.user
    @answers   = @timesheet.shift_answers.includes(:shift_question).where.not(answer_text: [ nil, "" ]).to_a

    mail(
      to: "ak@qcare.au",
      subject: "Issue on shift – #{@location&.name || 'Unknown location'} (#{@user&.name})"
    )
  end
end
