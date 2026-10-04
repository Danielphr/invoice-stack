require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  test "should require authentication" do
    get account_url

    assert_redirected_to new_session_url
  end

  test "should show the profile form with the current user's details" do
    sign_in_as users(:one)

    get account_url

    assert_response :success
    assert_select "h1", "Account"
    assert_select "#sidebar a[href=?][aria-current=page]", account_path, /John Doe/
    assert_select "form[action=?]", account_profile_path do
      assert_select "input[name=?][value=?]", "user[first_name]", "John"
      assert_select "input[name=?][value=?]", "user[email_address]", "one@example.com"
      assert_select "input[type=password][name=?]:not([required])", "user[password_challenge]"
    end
  end
end
