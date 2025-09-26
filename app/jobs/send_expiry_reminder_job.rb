class SendExpiryReminderJob < ApplicationJob
  queue_as :default

  def perform(user_id, kind)
    user = User.find_by(id: user_id)
    return unless user

    case kind.to_s
    when 'yellow'
      expiry = user.yellow_expiry
      subject = "Screening expiry for #{user.name}"
      body    = "#{user.name} Disability Screening check is about to expire on #{format_date(expiry)}. Make contact with the team member to remind them about renewal."
    when 'blue'
      expiry = user.blue_expiry
      subject = "Working with Children expiry for #{user.name}"
      body    = "#{user.name} Working with Children check is about to expire on #{format_date(expiry)}. Make contact with the team member to remind them about renewal."
    else
      return
    end

    return if expiry.blank?

    ComplianceMailer.with(user: user, subject: subject, body: body).reminder.deliver_later
  end

  private
  def format_date(dt)
    dt.in_time_zone.strftime('%-d %b %Y')
  end
end

