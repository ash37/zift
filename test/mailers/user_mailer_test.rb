require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  test "invitation_email" do
    mail = UserMailer.invitation_email
    assert_equal "Invitation email", mail.subject
    assert_equal [ "to@example.org" ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_match "Hi", mail.body.encoded
  end
end
