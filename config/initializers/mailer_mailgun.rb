if Rails.env.production?
  Rails.application.configure do
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address:              ENV.fetch("MAILGUN_SMTP_SERVER", "smtp.mailgun.org"),
      port:                 ENV.fetch("MAILGUN_SMTP_PORT", "587").to_i,
      user_name:            ENV["MAILGUN_SMTP_LOGIN"],
      password:             ENV["MAILGUN_SMTP_PASSWORD"],
      domain:               ENV.fetch("MAILGUN_DOMAIN"),
      authentication:       :plain,
      enable_starttls_auto: true
    }
    # Provide sensible fallbacks if env vars are missing
    default_from   = ENV["MAILER_FROM"].presence || "ak@qcare.au"
    default_reply  = ENV["MAILER_REPLY_TO"].presence
    options = { from: default_from }
    options[:reply_to] = default_reply if default_reply.present?
    config.action_mailer.default_options = options
  end
end
