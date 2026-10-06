require "application_system_test_case"

class DashboardTest < ApplicationSystemTestCase
  test "draws the revenue chart once Chart.js has loaded" do
    invoices(:globex_website).update!(status: "paid")
    sign_in_as users(:one)

    visit root_path

    # Chart.js sizes the canvas when it draws, so a sized canvas means the chart rendered.
    assert_selector "canvas[style*='width']", minimum: 1
  end
end
