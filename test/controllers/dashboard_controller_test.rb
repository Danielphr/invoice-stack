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
    assert_select "dl > div", text: /Outstanding\s+\$2,150.00 USD\s+1 invoice/
    assert_select "dl > div", text: /Overdue\s+\$2,150.00 USD\s+1 invoice/
    assert_select "dl dt svg[aria-hidden=true]", 4
    assert_select "dl > div", text: /Drafts\s+1/
    assert_select "a[href=?]", invoices_path(sort: "status", direction: "asc"), "Review drafts"
  end

  test "should filter revenue by period" do
    @user.company.invoices.create!(client: clients(:globex), currency: "USD", status: "paid", issue_date: Date.current,
      paid_on: Date.current, items_attributes: [ { description: "Work", quantity: 1, unit_price: 300 } ])

    get root_url(period: "month")

    assert_select "nav[aria-label=Period] a[aria-current=true]", "This month"
    assert_select "dt", "Revenue · This month"
    assert_select "dl > div", text: /\$300.00 USD\s+1 invoice/
  end

  test "should link to each period, with all time as the plain dashboard" do
    get root_url

    assert_select "nav[aria-label=Period] a[href=?][aria-current=true]", root_path, "All time"
    assert_select "nav[aria-label=Period] a[href=?]", root_path(period: "last_year"), "Last year"
  end

  test "should chart revenue over the period with an accessible table" do
    travel_to Date.new(2026, 10, 15) do
      @user.company.invoices.create!(client: clients(:globex), currency: "USD", status: "paid", issue_date: Date.current,
        paid_on: Date.current, items_attributes: [ { description: "Work", quantity: 1, unit_price: 300 } ])

      get root_url(period: "year")
    end

    assert_select "section h2", "Revenue over time"
    assert_select "section[data-controller=chart][data-chart-currency-value=USD]" do |chart|
      assert_equal (1..10).map { Date.new(2026, it).strftime("%b %Y") }, JSON.parse(chart.first["data-chart-labels-value"])
      assert_equal({ "USD" => [ 0.0 ] * 9 + [ 300.0 ] }, JSON.parse(chart.first["data-chart-series-value"]))
      assert_select "canvas[data-chart-target=canvas][aria-hidden=true]"
      assert_select "[role=group][aria-label=Currency]", count: 0
    end
    assert_select "section table.sr-only tr", 10
    assert_select "section table.sr-only tr", text: /October 2026\s*\$300.00 USD/
  end

  test "should offer a currency switch, starting on the company's default currency" do
    @user.company.update!(default_currency: "EUR")
    [ "USD", "EUR" ].each do |currency|
      @user.company.invoices.create!(client: clients(:globex), currency:, status: "paid", issue_date: Date.current,
        paid_on: Date.current, items_attributes: [ { description: "Work", quantity: 1, unit_price: 100 } ])
    end

    get root_url

    assert_select "section[data-controller=chart][data-chart-currency-value=EUR]"
    assert_select "[role=group][aria-label=Currency]" do
      assert_select "button[data-chart-currency-param=EUR][aria-pressed=true]", "EUR"
      assert_select "button[data-chart-currency-param=USD][aria-pressed=false]", "USD"
    end
    assert_select "table.sr-only caption", 2
  end

  test "should say when there are no payments to chart" do
    get root_url

    assert_select "section p", "No payments in this period."
    assert_select "[data-controller=chart]", count: 0
  end

  test "should show current user, company and log out" do
    get root_url

    assert_select "#sidebar", text: /#{@user.first_name} #{@user.last_name}/
    assert_select "#sidebar", text: /#{@user.company.name}/
    assert_select "#sidebar form[action=?] button", session_path, "Log out"
  end
end
