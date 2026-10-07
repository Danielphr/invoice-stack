require "test_helper"

class PasswordsMailerTest < ActionMailer::TestCase
  test "sends a reset link from InvoiceStack to the user" do
    user = users(:one)

    email = PasswordsMailer.reset(user)

    assert_equal [ user.email_address ], email.to
    assert_equal "InvoiceStack <no-reply@example.com>", email[:from].value
    assert_match %r{http://example.com/passwords/[^/]+/edit}, email.text_part.body.to_s
  end
end
