require "test_helper"

class Settings::PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "should change the password and sign out the other devices only" do
    other_device = @user.sessions.create!

    patch settings_password_url, params: { user: {
      password_challenge: "password", password: "a-new-long-password", password_confirmation: "a-new-long-password"
    } }

    assert_redirected_to settings_url
    assert @user.reload.authenticate("a-new-long-password")
    assert_not Session.exists?(other_device.id)
    assert Session.exists?(Current.session.id)

    follow_redirect!
    assert_select "[role=status]", "Password changed. You've been signed out on your other devices."
  end

  test "should require the current password" do
    patch settings_password_url, params: { user: { password: "a-new-long-password", password_confirmation: "a-new-long-password" } }

    assert_response :unprocessable_entity
    assert_select "form[action=?] [role=alert] li", settings_password_path, "Current password is invalid"
    assert_select "form[action=?] [role=alert]", settings_profile_path, count: 0
    assert @user.reload.authenticate("password")
  end

  test "should reject a short or unconfirmed new password" do
    patch settings_password_url, params: { user: {
      password_challenge: "password", password: "short", password_confirmation: "different"
    } }

    assert_response :unprocessable_entity
    assert_select "[role=alert] li", "Password is too short (minimum is 12 characters)"
    assert_select "[role=alert] li", "Password confirmation doesn't match Password"
    assert @user.reload.authenticate("password")
  end

  test "should give each form its own field ids" do
    get settings_url

    assert_select "#user_password_challenge", 1
    assert_select "#password_user_password_challenge", 1
    assert_select "label[for=password_user_password_challenge]", "Current password"
  end
end
