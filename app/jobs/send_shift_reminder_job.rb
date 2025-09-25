class SendShiftReminderJob < ApplicationJob
  queue_as :default

  def perform(user_id, shift_id)
    user = User.find_by(id: user_id)
    shift = Shift.find_by(id: shift_id)
    return unless user && shift

    # Idempotency
    ReminderSend.create!(user_id: user.id, shift_id: shift.id, kind: ReminderSend::KINDS[:pre_start_30])

    title = "Upcoming shift"
    location_name = shift.location&.name || 'your location'
    body = "You have a shift that starts in 30min with #{location_name}"
    payload = {
      shift_id: shift.id,
      starts_at: shift.start_time.iso8601,
      location_name: location_name,
      deeplink: Rails.application.routes.url_helpers.shift_path(shift)
    }

    user.push_subscriptions.active.find_each do |ps|
      begin
        Webpush.payload_send(
          message: { title: title, body: body, data: payload }.to_json,
          endpoint: ps.endpoint,
          p256dh: ps.p256dh,
          auth: ps.auth,
          vapid: {
            subject: "mailto:support@example.com",
            public_key: ENV.fetch('VAPID_PUBLIC_KEY'),
            private_key: ENV.fetch('VAPID_PRIVATE_KEY')
          }
        )
        ps.update_column(:last_used_at, Time.current)
      rescue Webpush::InvalidSubscription, Webpush::ExpiredSubscription, Webpush::ResponseError => e
        if e.respond_to?(:response) && [404,410].include?(e.response&.code.to_i)
          ps.update(active: false)
        else
          Rails.logger.error("Push send failed for subscription #{ps.id}: #{e.class}: #{e.message}")
        end
      end
    end
  end
end

