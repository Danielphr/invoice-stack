require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @company = @user.company
    sign_in_as @user
  end

  test "should require authentication" do
    sign_out

    get settings_url

    assert_redirected_to new_session_url
  end

  test "should show the preferences and invoice number settings" do
    @company.update!(time_zone: "Montevideo", invoice_number_pattern: "YP-{NUMBER}", invoice_number_digits: 4, next_invoice_number: 42)

    get settings_url

    assert_response :success
    assert_select "h1", "Settings"
    assert_select "nav a[aria-current=page]", "Settings"
    assert_select "form[action=?]", settings_path do
      assert_select "select[name=?] option[selected][value=?]", "company[time_zone]", "Montevideo"
      assert_select "select[name=?] option[selected][value=?]", "company[default_currency]", "USD"
      assert_select "input[name=?][value=?]", "company[invoice_number_pattern]", "YP-{NUMBER}"
      assert_select "input[name=?][min='2']", "company[next_invoice_number]"
    end
    assert_select "p", "Numbers below 2 are already used."
    assert_select "p", /Next invoice will be YP-0042/
  end

  test "should update the time zone and default currency" do
    patch settings_url, params: { company: { time_zone: "Montevideo", default_currency: "UYU" } }

    assert_redirected_to settings_url
    @company.reload
    assert_equal "Montevideo", @company.time_zone
    assert_equal "UYU", @company.default_currency
  end

  test "should update the invoice number settings" do
    patch settings_url, params: { company: {
      invoice_number_pattern: "YP-{YEAR}-{NUMBER}", invoice_number_digits: "3", next_invoice_number: "413"
    } }

    assert_redirected_to settings_url
    @company.reload
    assert_equal "YP-{YEAR}-{NUMBER}", @company.invoice_number_pattern
    assert_equal 3, @company.invoice_number_digits
    assert_equal 413, @company.next_invoice_number
  end

  test "should show errors for an invalid pattern" do
    patch settings_url, params: { company: { invoice_number_pattern: "INV-{YEAR}" } }

    assert_response :unprocessable_entity
    assert_select "[role=alert] li", "Number pattern must contain {NUMBER} exactly once"
    assert_equal "INV-{NUMBER}", @company.reload.invoice_number_pattern
  end

  test "should reject a next number too large to store" do
    patch settings_url, params: { company: { next_invoice_number: "9999999999" } }

    assert_response :unprocessable_entity
    assert_select "[role=alert] li", "Next number must be less than 1000000000"
  end

  test "should only change settings, not the company's details" do
    patch settings_url, params: { company: { name: "Renamed", time_zone: "Montevideo" } }

    assert_redirected_to settings_url
    assert_equal "Acme Inc.", @company.reload.name
  end

  test "should only change the current user's company" do
    other_company = companies(:other)

    patch settings_url, params: { company: { invoice_number_pattern: "MINE-{NUMBER}" } }

    assert_equal "INV-{NUMBER}", other_company.reload.invoice_number_pattern
  end
end
