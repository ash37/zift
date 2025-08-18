require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  test "invitation_email" do
    user = users(:one)
    mail = UserMailer.invitation_email(user)
    assert_equal "Qcare employment successful", mail.subject
    assert_equal [ user.email ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_match "Hi", mail.body.encoded
  end
end
