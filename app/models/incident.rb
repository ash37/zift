class Incident < ApplicationRecord
  EMAIL_REGEX = URI::MailTo::EMAIL_REGEXP

  with_options presence: true do
    validates :reporter_first_name
    validates :reporter_last_name
    validates :reporter_email, format: { with: EMAIL_REGEX }
    validates :category
    validates :details
    validates :incident_date
    validates :incident_address_line1
    validates :incident_suburb
    validates :incident_state
    validates :incident_postcode
  end

  validates :incident_postcode, length: { within: 3..10 }, allow_blank: true
end
