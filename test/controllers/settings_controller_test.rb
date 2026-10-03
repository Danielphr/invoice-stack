require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  test "should require authentication" do
    get settings_url

    assert_redirected_to new_session_url
  end

  test "should show the profile form with the current user's details" do
    sign_in_as users(:one)

    get settings_url

    assert_response :success
    assert_select "h1", "Settings"
    assert_select "nav a[aria-current=page]", "Settings"
    assert_select "form[action=?]", settings_profile_path do
      assert_select "input[name=?][value=?]", "user[first_name]", "John"
      assert_select "input[name=?][value=?]", "user[email_address]", "one@example.com"
      assert_select "input[type=password][name=?]:not([required])", "user[password_challenge]"
    end
  end
end
