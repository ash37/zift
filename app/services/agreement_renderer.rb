class AgreementRenderer
  # Very small, safe templating for agreements.
  # Supports placeholders like:
  #   {{ user.name }}, {{ user.first_name }}, {{ user.email }}, {{ date.today }}
  #   {{ acceptance.signed_at }} (only when available)
  # Unknown placeholders are left as-is.
  def self.render(agreement, user:, acceptance: nil, extra: {})
    template = agreement.body.to_s.dup

    context = build_context(user: user, acceptance: acceptance, extra: extra)
    template.gsub(/\{\{\s*([a-zA-Z0-9_\.]+)\s*\}\}/) do |match|
      path = Regexp.last_match(1)
      lookup(path, context) || match
    end
  end

  def self.build_context(user:, acceptance:, extra: {})
    # Normalize location if passed as object in extra
    location_hash = nil
    if extra && extra[:location].present?
      loc = extra[:location]
      # Expose common Location fields
      location_hash = {
        "id" => (loc.id if loc.respond_to?(:id)),
        "name" => (loc.name if loc.respond_to?(:name)),
        "address" => (loc.address if loc.respond_to?(:address)),
        "email" => (loc.email if loc.respond_to?(:email)),
        "phone" => (loc.phone if loc.respond_to?(:phone)),
        "status" => (loc.status if loc.respond_to?(:status)),
        "latitude" => (loc.latitude if loc.respond_to?(:latitude)),
        "longitude" => (loc.longitude if loc.respond_to?(:longitude)),
        "allowed_radius" => (loc.allowed_radius if loc.respond_to?(:allowed_radius)),
        "representative_name" => (loc.representative_name if loc.respond_to?(:representative_name)),
        "representative_email" => (loc.representative_email if loc.respond_to?(:representative_email)),
        "date_of_birth" => (loc.date_of_birth&.strftime("%-d %b %Y") if loc.respond_to?(:date_of_birth)),
        "ndis_number" => (loc.ndis_number if loc.respond_to?(:ndis_number)),
        "funding" => (loc.funding if loc.respond_to?(:funding)),
        "plan_manager_email" => (loc.plan_manager_email if loc.respond_to?(:plan_manager_email)),
        "interview_info" => (loc.interview_info if loc.respond_to?(:interview_info)),
        "schedule_info" => (loc.schedule_info if loc.respond_to?(:schedule_info)),
        "gender" => (loc.gender if loc.respond_to?(:gender)),
        "lives_with" => (loc.lives_with if loc.respond_to?(:lives_with)),
        "pets" => (loc.pets if loc.respond_to?(:pets)),
        "activities_of_interest" => (loc.activities_of_interest if loc.respond_to?(:activities_of_interest)),
        "tasks" => (loc.tasks if loc.respond_to?(:tasks))
      }.compact
    elsif extra && extra["location"].is_a?(Hash)
      location_hash = extra["location"]
    end

    {
      "user" => {
        "name" => user&.name,
        "first_name" => (user&.respond_to?(:first_name) ? user.first_name : nil),
        "last_name" => (user&.respond_to?(:last_name) ? user.last_name : nil),
        "email" => user&.email,
        "phone" => user&.phone
      },
      "date" => {
        "today" => Date.current.strftime("%-d %b %Y"),
        "now" => Time.current.strftime("%-d %b %Y %H:%M %Z")
      },
      "location" => (location_hash || {}),
      "acceptance" => (
        acceptance ? {
          "signed_name" => acceptance.signed_name,
          "signed_at" => acceptance.signed_at&.strftime("%-d %b %Y %H:%M %Z"),
          "ip_address" => acceptance.ip_address
        } : {}
      )
    }.merge(extra || {})
  end

  def self.lookup(path, context)
    keys = path.split(".")
    value = context
    keys.each do |k|
      return nil unless value.is_a?(Hash)
      value = value[k]
    end
    value.to_s if value
  end
end
