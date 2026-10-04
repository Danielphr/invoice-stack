require "test_helper"

class Account::ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "should update the name without the current password" do
    patch account_profile_url, params: { user: { first_name: "Johnny", last_name: "Doe" } }

    assert_redirected_to account_url
    assert_equal "Johnny", @user.reload.first_name
    follow_redirect!
    assert_select "[role=status]", "Profile updated."
  end

  test "should require the current password to change the email" do
    patch account_profile_url, params: { user: { email_address: "new@example.com" } }

    assert_response :unprocessable_entity
    assert_select "[role=alert] li", "Current password is invalid"
    assert_equal "one@example.com", @user.reload.email_address
  end

  test "should reject a wrong current password" do
    patch account_profile_url, params: { user: { email_address: "new@example.com", password_challenge: "wrong" } }

    assert_response :unprocessable_entity
    assert_equal "one@example.com", @user.reload.email_address
  end

  test "should change the email with the current password" do
    patch account_profile_url, params: { user: { email_address: "new@example.com", password_challenge: "password" } }

    assert_redirected_to account_url
    assert_equal "new@example.com", @user.reload.email_address
  end

  test "should keep the saved name in the sidebar when the form has errors" do
    patch account_profile_url, params: { user: { first_name: "" } }

    assert_response :unprocessable_entity
    assert_select "form[action=?] [role=alert] li", account_profile_path, "First name can't be blank"
    assert_select "#sidebar a[href=?][aria-current=page]", account_path
    assert_select "form[action=?] [role=alert]", account_password_path, count: 0
    assert_select "#sidebar", /John Doe/
  end

  test "should only change the signed-in user" do
    other = users(:two)

    patch account_profile_url, params: { user: { first_name: "Hacked", id: other.id } }

    assert_equal "Jane", other.reload.first_name
  end
end
