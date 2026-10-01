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

  test "should highlight Invoices in the navigation on invoice pages" do
    [ invoices_url, new_invoice_url, invoice_url(@invoice), edit_invoice_url(@invoice) ].each do |url|
      get url

      assert_select "nav a[aria-current=page]", "Invoices"
    end
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

  test "should get new with today's date, the default currency and one empty item" do
    get new_invoice_url

    assert_response :success
    assert_select "input[name=?][value=?]", "invoice[issue_date]", Date.current.iso8601
    assert_select "select[name=?] option[selected][value=?]", "invoice[currency]", "USD"
    assert_select "tbody tr[data-invoice-form-target=item]", 1
    assert_select "select[name=?] option", "invoice[client_id]", text: "Wayne Enterprises", count: 0
  end

  test "should label item inputs with their column headers" do
    @invoice.update!(billing_type: "hourly")

    get edit_invoice_url(@invoice)

    assert_select "th#item-quantity-header", "Hours"
    assert_select "th#item-unit-price-header", "Rate"
    assert_select "tbody input[name$='[quantity]'][aria-labelledby=item-quantity-header]", 2
    assert_select "tbody input[name$='[unit_price]'][aria-labelledby=item-unit-price-header]", 2
  end

  test "should ask for a client first when the company has none" do
    @user.company.invoices.destroy_all
    @user.company.clients.destroy_all

    get new_invoice_url

    assert_select "form[action=?]", invoices_path, count: 0
    assert_select "h2", "Add a client first"
  end

  test "should create an invoice with its items" do
    assert_difference({ "Invoice.count" => 1, "InvoiceItem.count" => 2 }) do
      post invoices_url, params: { invoice: invoice_params(items_attributes: {
        "0" => { description: "Design", quantity: "1", unit_price: "500" },
        "1" => { description: "Support", quantity: "3", unit_price: "40.5" }
      }) }
    end

    invoice = Invoice.order(:created_at).last
    assert_redirected_to invoice_url(invoice)
    assert_equal @user.company, invoice.company
    assert_equal [ "Design", "Support" ], invoice.items.map(&:description)
    assert_equal BigDecimal("621.50"), invoice.total
  end

  test "should not create an invoice without items" do
    assert_no_difference "Invoice.count" do
      post invoices_url, params: { invoice: invoice_params }
    end

    assert_response :unprocessable_entity
    assert_select "[role=alert] li", "Add at least one item"
  end

  test "should not create an invoice for another company's client" do
    assert_no_difference "Invoice.count" do
      post invoices_url, params: { invoice: invoice_params(
        client_id: clients(:other_company_client).id,
        items_attributes: { "0" => { description: "Design", quantity: "1", unit_price: "500" } }
      ) }
    end

    assert_response :unprocessable_entity
    assert_select "[role=alert] li", "Client is invalid"
  end

  test "should update an invoice, adding, changing and removing items" do
    design, development = @invoice.items

    patch invoice_url(@invoice), params: { invoice: { billing_type: "hourly", items_attributes: {
      "0" => { id: design.id, description: "Website design", quantity: "1", unit_price: "1200" },
      "1" => { id: development.id, _destroy: "1" },
      "2" => { description: "Hosting", quantity: "1", unit_price: "100" }
    } } }

    assert_redirected_to invoice_url(@invoice)
    @invoice.reload
    assert @invoice.hourly?
    assert_equal [ "Website design", "Hosting" ], @invoice.items.map(&:description)
    assert_not InvoiceItem.exists?(development.id)
  end

  test "should not update an invoice with invalid data" do
    patch invoice_url(@invoice), params: { invoice: { due_date: @invoice.issue_date - 1 } }

    assert_response :unprocessable_entity
    assert_select "[role=alert] li", "Due date can't be before the issue date"
  end

  test "should not change items that belong to another invoice" do
    other_item = invoice_items(:other_company_consulting)

    patch invoice_url(@invoice), params: { invoice: { items_attributes: {
      "0" => { id: other_item.id, description: "Hacked" }
    } } }

    assert_response :not_found
    assert_equal "Consulting", other_item.reload.description
  end

  test "should not edit or update another company's invoice" do
    get edit_invoice_url(@other_invoice)
    assert_response :not_found

    patch invoice_url(@other_invoice), params: { invoice: { number: "HACKED" } }
    assert_response :not_found
    assert_equal "INV-001", @other_invoice.reload.number
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

  private
    def invoice_params(**overrides)
      { client_id: clients(:globex).id, number: "INV-100", currency: "USD", issue_date: "2026-10-01" }.merge(overrides)
    end
end
