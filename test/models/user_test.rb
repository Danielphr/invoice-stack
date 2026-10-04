require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "requires a password of at least 12 characters when one is set" do
    user = users(:one)

    user.password = "eleven-char"
    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 12 characters)"

    user.password = "twelve-chars"
    assert user.valid?
  end

  test "keeps a shorter existing password valid while it isn't changed" do
    user = users(:one)
    user.first_name = "Johnny"

    assert user.valid?
  end

  test "requires a valid email address" do
    user = users(:one)
    user.email_address = "not an email"

    assert_not user.valid?
    assert_includes user.errors[:email_address], "is invalid"
  end

  test "joins the full name and builds initials" do
    user = User.new(first_name: "ada", last_name: "Lovelace")

    assert_equal "ada Lovelace", user.full_name
    assert_equal "AL", user.initials
  end
end
