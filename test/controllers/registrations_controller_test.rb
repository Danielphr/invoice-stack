require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get new_registration_url

    assert_response :success
    assert_select "a[href=?]", new_session_path
  end

  test "should create user and company" do
    assert_difference [ "User.count", "Company.count" ], 1 do
      post registration_url, params: {
        user: {
          first_name: "John",
          last_name: "Doe",
          email_address: "john@example.com",
          password: "correct-horse-battery",
          password_confirmation: "correct-horse-battery"
        }
      }
    end

    assert_redirected_to onboarding_url
  end

  test "should not create user or company with invalid parameters" do
    assert_no_difference [ "User.count", "Company.count" ] do
      post registration_url, params: {
        user: {
          first_name: "John",
          last_name: "Doe",
          email_address: "",
          password: "correct-horse-battery",
          password_confirmation: "correct-horse-battery"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "[role=alert] li", "Email address can't be blank"
    assert_select "input[name=?][value=?]", "user[first_name]", "John"
  end

  test "should show an error for an email address that is already taken" do
    assert_no_difference [ "User.count", "Company.count" ] do
      post registration_url, params: {
        user: {
          first_name: "John",
          last_name: "Doe",
          email_address: users(:one).email_address.upcase,
          password: "correct-horse-battery",
          password_confirmation: "correct-horse-battery"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "[role=alert] li", "Email address has already been taken"
  end

  test "should turn sign-up away when it's closed" do
    with_sign_ups(false) do
      get new_registration_url
      assert_redirected_to new_session_url
      assert_equal "Sign-up is closed.", flash[:alert]

      assert_no_difference "User.count" do
        post registration_url, params: { user: { first_name: "John", last_name: "Doe", email_address: "john@example.com",
          password: "correct-horse-battery", password_confirmation: "correct-horse-battery" } }
      end
      assert_redirected_to new_session_url

      get new_session_url
      assert_select "a[href=?]", new_registration_path, count: 0
    end
  end

  private
    def with_sign_ups(enabled)
      previous = Rails.configuration.x.sign_ups_enabled
      Rails.configuration.x.sign_ups_enabled = enabled
      yield
    ensure
      Rails.configuration.x.sign_ups_enabled = previous
    end
end
