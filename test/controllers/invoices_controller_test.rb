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

  test "should show each invoice's billing type in the list" do
    @invoice.update!(billing_type: "hourly")

    get invoices_url

    assert_select "thead th", "Billing"
    assert_select "tbody td", "Hourly"
  end

  test "should sort by number, newest first, by default" do
    newer = @user.company.invoices.create!(client: clients(:initech), currency: "USD", issue_date: Date.new(2026, 8, 1),
      items_attributes: [ { description: "Support", quantity: 1, unit_price: 100 } ])

    get invoices_url

    assert_select "th[aria-sort=descending]", /Number/
    assert_select "th[aria-sort]", 1
    assert_select "tbody tr:first-child", /#{newer.number}/
    assert_select "th a[href=?]", invoices_path(sort: "number", direction: "asc")
  end

  test "should sort by the chosen column and link to the opposite direction" do
    get invoices_url(sort: "client", direction: "asc")

    assert_response :success
    assert_select "th[aria-sort=ascending]", /Client/
    assert_select "th a[href=?]", invoices_path(sort: "client", direction: "desc")
    assert_select "th a[href=?]", invoices_path(sort: "issued", direction: "asc")
  end

  test "should sort by total" do
    get invoices_url(sort: "total", direction: "desc")

    assert_response :success
    assert_select "th.text-right[aria-sort=descending]", /Total/
    assert_select "tbody tr", /\$2,150.00 USD/
  end

  test "should fall back to the default sort for unknown parameters" do
    get invoices_url(sort: "number; DROP TABLE invoices", direction: "sideways")

    assert_response :success
    assert_select "th[aria-sort=descending]", /Number/
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

  test "should remind the user when the company address is missing" do
    get invoice_url(@invoice)
    assert_select "[role=note] a[href=?]", company_path

    @user.company.update!(address_line1: "100 Example Street", city: "Springfield", country: "US")
    get invoice_url(@invoice)
    assert_select "[role=note]", count: 0
  end

  test "should render an invoice as a PDF" do
    get invoice_url(@invoice, format: :pdf)

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_match(/\Ainline; filename="INV-001.pdf"/, response.headers["Content-Disposition"])
    assert response.body.start_with?("%PDF")
  end

  test "should link to each invoice's PDF from the list" do
    get invoices_url

    assert_select "tbody a[href=?][target=_blank]", invoice_path(@invoice, format: :pdf), text: /PDF/
  end

  test "should offer to edit and delete each invoice from the list" do
    @invoice.update!(status: "sent")

    get invoices_url

    assert_select "tbody a[href=?]", edit_invoice_path(@invoice), text: /Edit/
    assert_select "tbody form[action=?][data-turbo-confirm=?]", invoice_path(@invoice),
      "Invoice INV-001 has been sent. Deleting it removes it permanently and leaves a gap in your numbering. " \
      "Consider cancelling it instead." do
      assert_select "input[name=_method][value=delete]"
      assert_select "button", /Delete/
    end
  end

  test "should link to the PDF from the invoice page" do
    get invoice_url(@invoice)

    assert_select "a[href=?][target=_blank]", invoice_path(@invoice, format: :pdf), "PDF"
  end

  test "should not render another company's invoice as a PDF" do
    get invoice_url(@other_invoice, format: :pdf)

    assert_response :not_found
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
    assert_select "input[name=?][value=?]", "invoice[issue_date]", Time.find_zone(@user.company.time_zone).today.iso8601
    assert_select "select[name=?] option[selected][value=?]", "invoice[currency]", "USD"
    assert_select "tbody tr[data-invoice-form-target=item]", 1
    assert_select "select[name=?] option", "invoice[client_id]", text: "Wayne Enterprises", count: 0
  end

  test "should default new invoices to the company's currency" do
    @user.company.update!(default_currency: "UYU")

    get new_invoice_url

    assert_select "select[name=?] option[selected][value=?]", "invoice[currency]", "UYU"
  end

  test "should use the company's time zone for today's date" do
    travel_to Time.utc(2026, 10, 2, 1, 0) do
      @user.company.update!(time_zone: "Montevideo")
      get new_invoice_url
      assert_select "input[name=?][value=?]", "invoice[issue_date]", "2026-10-01"

      @user.company.update!(time_zone: "Tokyo")
      get new_invoice_url
      assert_select "input[name=?][value=?]", "invoice[issue_date]", "2026-10-02"
    end
  end

  test "should decide overdue in the company's time zone" do
    @invoice.update!(due_date: Date.new(2026, 10, 1), issue_date: Date.new(2026, 9, 1))

    travel_to Time.utc(2026, 10, 2, 1, 0) do
      @user.company.update!(time_zone: "Montevideo")
      get invoices_url
      assert_select "tbody span", text: "Overdue", count: 0

      @user.company.update!(time_zone: "UTC")
      get invoices_url
      assert_select "tbody span", text: "Overdue"
    end
  end

  test "should show the next number in a locked field on new" do
    get new_invoice_url

    assert_select "input[name=?][readonly][placeholder=?]", "invoice[number]", "INV-1"
    assert_select "button", "Override"
    assert_select "[data-field-override-target=warning][hidden]"
  end

  test "should show the current number in a locked field on edit" do
    get edit_invoice_url(@invoice)

    assert_select "input[name=?][readonly][value=?]", "invoice[number]", "INV-001"
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
    assert_equal "INV-1", invoice.number
    assert_equal [ "Design", "Support" ], invoice.items.map(&:description)
    assert_equal BigDecimal("621.50"), invoice.total
  end

  test "should create an invoice with an overridden number" do
    post invoices_url, params: { invoice: invoice_params(number: "SPECIAL-1", items_attributes: {
      "0" => { description: "Design", quantity: "1", unit_price: "500" }
    }) }

    assert_equal "SPECIAL-1", Invoice.order(:created_at).last.number
    assert_equal 1, @user.company.reload.next_invoice_number
  end

  test "should reject an overridden number that is already used and keep the field unlocked" do
    assert_no_difference "Invoice.count" do
      post invoices_url, params: { invoice: invoice_params(number: "INV-001", items_attributes: {
        "0" => { description: "Design", quantity: "1", unit_price: "500" }
      }) }
    end

    assert_response :unprocessable_entity
    assert_select "[role=alert] li", "Number has already been taken"
    assert_select "input[name=?][value=?]:not([readonly])", "invoice[number]", "INV-001"
    assert_select "[data-field-override-target=warning]:not([hidden])"
  end

  test "should not allow removing the number of an existing invoice" do
    patch invoice_url(@invoice), params: { invoice: { number: "" } }

    assert_response :unprocessable_entity
    assert_select "[role=alert] li", "Number can't be blank"
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

  test "should show and edit the payment date of a paid invoice" do
    @invoice.update!(status: "paid", paid_on: Date.new(2026, 9, 20))

    get invoice_url(@invoice)
    assert_select "dd", "Sep 20, 2026"

    get edit_invoice_url(@invoice)
    assert_select "input[name=?][value=?]", "invoice[paid_on]", "2026-09-20"

    patch invoice_url(@invoice), params: { invoice: { paid_on: "2026-09-25" } }
    assert_equal Date.new(2026, 9, 25), @invoice.reload.paid_on
  end

  test "should not show a payment date field for unpaid invoices" do
    get edit_invoice_url(@invoice)

    assert_select "input[name=?]", "invoice[paid_on]", count: 0
  end

  test "should warn when editing an invoice that was already sent" do
    get edit_invoice_url(@invoice)
    assert_select "[role=note]", /This invoice has been sent/

    @invoice.update!(status: "draft")
    get edit_invoice_url(@invoice)
    assert_select "[role=note]", count: 0
  end

  test "should ask for a stronger confirmation before deleting a sent invoice" do
    get invoice_url(@invoice)

    assert_select "form[data-turbo-confirm*=?]", "Consider cancelling it instead."
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
      { client_id: clients(:globex).id, currency: "USD", issue_date: "2026-10-01" }.merge(overrides)
    end
end
