require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "new" do
    get new_session_path
    assert_response :success
    assert_select "h1", "Sign in to your account"
    assert_select "a[href=?]", new_registration_path
    assert_select "a[href=?]", new_password_path
    assert_select "[data-controller=password-visibility]" do
      assert_select "input[type=password][name=password][required]"
      assert_select "button[type=button][aria-label=?]", "Show password"
    end
  end

  test "create with valid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create with invalid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "wrong" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]

    follow_redirect!
    assert_select "[role=alert]", /Try another email address or password/
  end

  test "destroy" do
    sign_in_as(User.take)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end

  test "should allow user with incomplete onboarding to sign out" do
    sign_in_as users(:incomplete)

    delete session_url

    assert_redirected_to new_session_url

    get root_url
    assert_redirected_to new_session_url
  end
end
