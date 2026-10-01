require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get new_registration_url

    assert_response :success
  end

  test "should create user and company" do
    assert_difference [ "User.count", "Company.count" ], 1 do
      post registration_url, params: {
        user: {
          first_name: "John",
          last_name: "Doe",
          email_address: "john@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_redirected_to root_url
  end

  test "should not create user or company with invalid parameters" do
    assert_no_difference [ "User.count", "Company.count" ] do
      post registration_url, params: {
        user: {
          first_name: "John",
          last_name: "Doe",
          email_address: "",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_response :unprocessable_entity
  end
end
