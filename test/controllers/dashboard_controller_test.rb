require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "should show navigation with the current page marked" do
    get root_url

    assert_response :success
    assert_select "title", "Dashboard · InvoiceStack"
    assert_select "#sidebar a[href=?] img[alt=InvoiceStack][src*=logo-light]", root_path
    assert_select "nav a[aria-current=page]", count: 1
    assert_select "nav a[aria-current=page]", "Dashboard"
    assert_select "nav a svg[aria-hidden=true]", 5
    assert_select "nav[aria-label=Account] a[href=?]", settings_path, "Settings"
    assert_select "nav a[href=?]", company_path, "Company"
    assert_select "nav a[href=?]", clients_path, "Clients"
    assert_select "nav a[href=?]", invoices_path, "Invoices"
  end

  test "should show revenue, outstanding, overdue and draft totals" do
    travel_to Date.new(2026, 10, 15) do
      get root_url
    end

    assert_select "dt", "Revenue · All time"
    assert_select "dl > div", text: /No payments/
    assert_select "dl > div", text: /Due soon\s+Nothing due\s+0 invoices/
    assert_select "dl > div", text: /Overdue\s+\$2,150.00 USD\s+1 invoice/
    assert_select "dl dt svg[aria-hidden=true]", 3
  end

  test "should filter revenue by period" do
    paid(300)

    get root_url(period: "month")

    assert_select "nav[aria-label=Period] a[aria-current=true]", "This month"
    assert_select "dt", "Revenue · This month"
    assert_select "dl > div", text: /\$300.00 USD\s+1 invoice/
  end

  test "should link to each period, with all time as the plain dashboard" do
    get root_url

    assert_select "nav[aria-label=Period] a[href=?][aria-current=true]", root_path, "All time"
    assert_select "nav[aria-label=Period] a[href=?]", root_path(period: "last_year"), "Last year"
    assert_select "nav[aria-label=Currency]", count: 0
  end

  test "should switch the whole dashboard between currencies, keeping the period" do
    paid(300)
    paid(80, currency: "EUR")

    get root_url(period: "month", currency: "EUR")

    assert_select "nav[aria-label=Currency]" do
      assert_select "a[href=?][aria-current=true]", root_path(period: "month", currency: "EUR"), "EUR"
      assert_select "a[href=?]", root_path(period: "month", currency: "USD"), "USD"
    end
    assert_select "nav[aria-label=Period] a[href=?]", root_path(currency: "EUR"), "All time"
    assert_select "dl > div", text: /€80.00 EUR\s+1 invoice/
    assert_select "section[data-chart-currency-value=EUR]", 2
  end

  test "should chart revenue over the period with an accessible table" do
    travel_to Date.new(2026, 10, 15) do
      paid(300)
      get root_url(period: "year")
    end

    assert_select "section h2", "Revenue over time"
    assert_select "section[data-controller=chart][data-chart-currency-value=USD]:not([data-chart-type-value])" do |chart|
      assert_equal (1..10).map { Date.new(2026, it).strftime("%b %Y") }, JSON.parse(chart.first["data-chart-labels-value"])
      assert_equal [ 0.0 ] * 9 + [ 300.0 ], JSON.parse(chart.first["data-chart-amounts-value"])
      assert_select "canvas[data-chart-target=canvas][aria-hidden=true]"
    end
    assert_select "section table.sr-only tr", 10
    assert_select "section table.sr-only tr", text: /October 2026\s*\$300.00 USD/
  end

  test "should rank clients by revenue with a legend" do
    paid(300, client: clients(:initech))
    paid(100)

    get root_url

    assert_select "section[data-chart-type-value=bars]" do |chart|
      assert_equal [ "Initech", "Globex Corporation" ], JSON.parse(chart.first["data-chart-labels-value"])
      assert_equal [ 300.0, 100.0 ], JSON.parse(chart.first["data-chart-amounts-value"])
      assert_equal [ "#9c42e5", "#06b6d4" ], JSON.parse(chart.first["data-chart-colors-value"])
      assert_select "h2", "Revenue by client"
      assert_select "li", text: /Initech\s+\$300.00 USD\s+75%/
      assert_select "li a[href=?]", client_path(clients(:initech))
    end
  end

  test "should show needs attention at the top, collapsed, in every currency" do
    euros = nil
    travel_to Date.new(2026, 10, 15) do
      euros = @user.company.invoices.create!(client: clients(:initech), currency: "EUR", status: "sent", issue_date: Date.current,
        due_date: Date.current + 3, items_attributes: [ { description: "Work", quantity: 1, unit_price: 100 } ])

      get root_url(currency: "USD", period: "month")
    end

    assert_select "details:not([open]).border-red-200 summary h2", "Needs attention"
    assert_select "details summary", text: /1 overdue\s+1 due soon/
    assert_select "details li", text: /INV-001\s+Globex Corporation\s+\$2,150.00 USD\s+15 days overdue/
    assert_select "details li a[href=?]", invoice_path(euros), euros.number
    assert_select "details li", text: /€100.00 EUR\s+Due in 3 days/
    assert css_select("details").first.ancestors.none? { it.name == "dl" }, "needs attention should sit outside the filtered numbers"
  end

  test "should outline needs attention in amber when nothing is overdue" do
    travel_to Date.new(2026, 9, 20) do
      get root_url
    end

    assert_select "details:not([open]).border-amber-200 summary", text: /1 due soon/
  end

  test "should link to the rest when more than five invoices need attention" do
    travel_to Date.new(2026, 10, 15) do
      6.times do
        @user.company.invoices.create!(client: clients(:globex), currency: "USD", status: "sent", issue_date: Date.current,
          due_date: Date.current, items_attributes: [ { description: "Work", quantity: 1, unit_price: 10 } ])
      end

      get root_url
    end

    assert_select "details a[href=?]", invoices_path(sort: "due", direction: "asc"), "+1 more"
  end

  test "should say when nothing needs attention" do
    remove_invoices(@user.company)

    get root_url

    assert_select "details", count: 0
    assert_select "section[aria-labelledby=attention-heading] p", "Nothing right now. All sent invoices are on time."
  end

  test "should say when there is nothing to chart" do
    get root_url

    assert_select "section p", text: "No payments in this period.", count: 2
    assert_select "[data-controller=chart]", count: 0
  end

  test "should show current user, company and log out" do
    get root_url

    assert_select "#sidebar", text: /#{@user.first_name} #{@user.last_name}/
    assert_select "#sidebar", text: /#{@user.company.name}/
    assert_select "#sidebar form[action=?] button", session_path, "Log out"
  end

  private
    def paid(amount, client: clients(:globex), currency: "USD")
      @user.company.invoices.create!(client:, currency:, status: "paid", issue_date: Date.current, paid_on: Date.current,
        items_attributes: [ { description: "Work", quantity: 1, unit_price: amount } ])
    end
end
