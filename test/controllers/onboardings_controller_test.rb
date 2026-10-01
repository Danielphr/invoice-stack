require "test_helper"

class OnboardingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:incomplete)
    sign_in_as @user
  end

  test "should show onboarding for incomplete company" do
    get onboarding_url

    assert_response :success
  end

  test "should offer log out without app navigation" do
    get onboarding_url

    assert_select "form[action=?] button", session_path, "Log out"
    assert_select "#sidebar", count: 0
  end

  test "should update company and redirect to root" do
    patch onboarding_url, params: {
      company: {
        name: "Acme Inc."
      }
    }

    assert_redirected_to root_url
    assert_equal "Acme Inc.", @user.company.reload.name
    assert @user.company.onboarding_complete?
  end

  test "should not complete onboarding with blank company name" do
    patch onboarding_url, params: {
      company: {
        name: ""
      }
    }

    assert_response :unprocessable_entity
    assert_select "[role=alert] li", "Company name can't be blank"
    assert_not @user.company.reload.onboarding_complete?
  end

  test "should redirect completed company away from onboarding" do
    @user.company.update!(name: "Acme Inc.")

    get onboarding_url

    assert_redirected_to root_url
  end

  test "should require authentication" do
    delete session_url

    get onboarding_url

    assert_redirected_to new_session_url
  end
end
