class ApplicationMailer < ActionMailer::Base
  default from: "from@example.com"
  layout "mailer"

  helper_method :format_shift_time

  def format_shift_time(time)
    time.strftime("%-l:%M%P")
  end
end
