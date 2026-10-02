require "test_helper"

class CompaniesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @company = @user.company
    sign_in_as @user
  end

  test "should require authentication" do
    sign_out

    get company_url

    assert_redirected_to new_session_url
  end

  test "should show the invoice number settings and the next number" do
    @company.update!(invoice_number_pattern: "YP-{NUMBER}", invoice_number_digits: 4, next_invoice_number: 42)

    get company_url

    assert_response :success
    assert_select "h1", @company.name
    assert_select "input[name=?][value=?]", "company[invoice_number_pattern]", "YP-{NUMBER}"
    assert_select "p", /Next invoice will be YP-0042/
    assert_select "nav a[aria-current=page]", "Company"
  end

  test "should update the invoice number settings" do
    patch company_url, params: { company: {
      invoice_number_pattern: "YP-{YEAR}-{NUMBER}", invoice_number_digits: "3", next_invoice_number: "413"
    } }

    assert_redirected_to company_url
    @company.reload
    assert_equal "YP-{YEAR}-{NUMBER}", @company.invoice_number_pattern
    assert_equal 3, @company.invoice_number_digits
    assert_equal 413, @company.next_invoice_number
  end

  test "should show errors for an invalid pattern" do
    patch company_url, params: { company: { invoice_number_pattern: "INV-{YEAR}" } }

    assert_response :unprocessable_entity
    assert_select "[role=alert] li", "Number pattern must contain {NUMBER} exactly once"
    assert_equal "INV-{NUMBER}", @company.reload.invoice_number_pattern
  end

  test "should only change the current user's company" do
    other_company = companies(:other)

    patch company_url, params: { company: { invoice_number_pattern: "MINE-{NUMBER}" } }

    assert_equal "INV-{NUMBER}", other_company.reload.invoice_number_pattern
  end
end
