require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "should show navigation with the current page marked" do
    get root_url

    assert_response :success
    assert_select "title", "InvoiceStack"
    assert_select "nav a[aria-current=page]", "Dashboard"
  end

  test "should show current user, company and log out" do
    get root_url

    assert_select "#sidebar", text: /#{@user.first_name} #{@user.last_name}/
    assert_select "#sidebar", text: /#{@user.company.name}/
    assert_select "#sidebar form[action=?] button", session_path, "Log out"
  end
end
