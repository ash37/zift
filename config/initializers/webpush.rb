if ENV['VAPID_PUBLIC_KEY'].present? && ENV['VAPID_PRIVATE_KEY'].present?
  Webpush.configure do |config|
    config.vapid_public_key = ENV['VAPID_PUBLIC_KEY']
    config.vapid_private_key = ENV['VAPID_PRIVATE_KEY']
  end
end

