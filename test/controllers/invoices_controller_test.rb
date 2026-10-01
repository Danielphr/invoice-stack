require "test_helper"

class InvoicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @invoice = invoices(:globex_website)
    @other_invoice = invoices(:other_company_invoice)
    sign_in_as @user
  end

  test "should require authentication" do
    sign_out

    get invoices_url

    assert_redirected_to new_session_url
  end

  test "should list only the company's invoices" do
    get invoices_url

    assert_response :success
    assert_select "tbody tr", 1
    assert_select "tbody tr", /INV-001/
    assert_select "tbody tr", /Globex Corporation/
    assert_select "tbody tr", /\$2,150.00 USD/
    assert_select "tbody", text: /Wayne Enterprises/, count: 0
  end

  test "should show an empty state when there are no invoices" do
    @user.company.invoices.destroy_all

    get invoices_url

    assert_select "table", count: 0
    assert_select "h2", "No invoices yet"
  end

  test "should show an invoice with its items and totals" do
    get invoice_url(@invoice)

    assert_response :success
    assert_select "h1", "Invoice INV-001"
    assert_select "tbody tr", 2
    assert_select "th", "Quantity"
    assert_select "dd", "$2,200.00 USD"
    assert_select "dd", "−$50.00 USD"
    assert_select "dd", "$2,150.00 USD"
  end

  test "should label item columns for hourly invoices" do
    @invoice.update!(billing_type: "hourly")

    get invoice_url(@invoice)

    assert_select "th", "Hours"
    assert_select "th", "Rate"
  end

  test "should destroy an invoice and its items" do
    assert_difference({ "Invoice.count" => -1, "InvoiceItem.count" => -2 }) do
      delete invoice_url(@invoice)
    end

    assert_redirected_to invoices_url
  end

  test "should not expose or delete another company's invoice" do
    get invoice_url(@other_invoice)
    assert_response :not_found

    assert_no_difference "Invoice.count" do
      delete invoice_url(@other_invoice)
    end
    assert_response :not_found
  end
end
