require "test_helper"

class DashboardTest < ActiveSupport::TestCase
  setup do
    @company = companies(:one)
    travel_to Date.new(2026, 10, 15)
  end

  test "counts revenue by payment date within the period" do
    paid(100, paid_on: Date.new(2026, 10, 3))
    paid(200, paid_on: Date.new(2026, 7, 1))
    paid(300, paid_on: Date.new(2025, 12, 20), issue_date: Date.new(2025, 12, 1))

    assert_equal 100, revenue_for("month")
    assert_equal 100, revenue_for("quarter")
    assert_equal 300, revenue_for("year")
    assert_equal 300, revenue_for("last_year")
    assert_equal 600, revenue_for("all")
    assert_equal 1, Dashboard.new(@company, period: "month").revenue.count
  end

  test "counts a payment in the month it was received, not the month it was issued" do
    paid(100, issue_date: Date.new(2026, 9, 20), paid_on: Date.new(2026, 10, 2))

    assert_equal 100, revenue_for("month")
  end

  test "falls back to all time for an unknown period" do
    assert_equal "all", Dashboard.new(@company, period: "decade").period
  end

  test "shows one currency at a time, starting with the company's default" do
    paid(100, paid_on: Date.new(2026, 10, 3))
    paid(70, paid_on: Date.new(2026, 10, 4), currency: "EUR")

    assert_equal %w[ USD EUR ], Dashboard.new(@company).currencies
    assert_equal "USD", Dashboard.new(@company).currency
    assert_equal 70, Dashboard.new(@company, currency: "EUR").revenue.total
    assert_equal "USD", Dashboard.new(@company, currency: "XYZ").currency
  end

  test "offers the company's currency first and starts on it, even without invoices in it" do
    remove_invoices(@company)
    paid(70, paid_on: Date.new(2026, 10, 4), currency: "EUR")
    paid(50, paid_on: Date.new(2026, 10, 4), currency: "BRL")

    dashboard = Dashboard.new(@company)

    assert_equal %w[ USD BRL EUR ], dashboard.currencies
    assert_equal "USD", dashboard.currency
  end

  test "summarizes invoices due soon and overdue in the currency" do
    create_invoice(500, status: "sent", issue_date: Date.new(2026, 10, 1), due_date: Date.new(2026, 10, 29))
    create_invoice(800, status: "sent", issue_date: Date.new(2026, 10, 1), due_date: Date.new(2026, 10, 30))
    create_invoice(90, status: "sent", issue_date: Date.new(2026, 10, 1), due_date: Date.new(2026, 10, 20), currency: "EUR")
    dashboard = Dashboard.new(@company)

    assert_equal [ 1, 500 ], [ dashboard.due_soon.count, dashboard.due_soon.total ]
    assert_equal [ 1, 2150 ], [ dashboard.overdue.count, dashboard.overdue.total ]
  end

  test "charts revenue by month over the period, including empty months" do
    paid(100, paid_on: Date.new(2026, 10, 3))
    paid(300, paid_on: Date.new(2026, 2, 20))
    paid(999, paid_on: Date.new(2025, 12, 31), issue_date: Date.new(2025, 12, 1))
    paid(50, paid_on: Date.new(2026, 10, 10), currency: "EUR")

    series = Dashboard.new(@company, period: "year").revenue_over_time

    assert_equal (1..10).map { Date.new(2026, it, 1) }, series.keys
    assert_equal [ 300, 0, 100 ], [ series[Date.new(2026, 2, 1)], series[Date.new(2026, 5, 1)], series[Date.new(2026, 10, 1)] ]
  end

  test "charts this month by day, up to today" do
    paid(100, paid_on: Date.new(2026, 10, 3))

    dashboard = Dashboard.new(@company, period: "month")
    series = dashboard.revenue_over_time

    assert dashboard.chart_by_day?
    assert_equal (1..15).map { Date.new(2026, 10, it) }, series.keys
    assert_equal 100, series[Date.new(2026, 10, 3)]
  end

  test "charts all time from the month of the first payment" do
    paid(300, paid_on: Date.new(2026, 8, 20))

    assert_equal [ Date.new(2026, 8, 1), Date.new(2026, 9, 1), Date.new(2026, 10, 1) ],
      Dashboard.new(@company).revenue_over_time.keys
  end

  test "has nothing to chart for all time without payments" do
    assert_empty Dashboard.new(@company).revenue_over_time
  end

  test "ranks the top clients in the currency" do
    paid(100, paid_on: Date.new(2026, 10, 3), client: clients(:globex))
    paid(400, paid_on: Date.new(2026, 10, 4), client: clients(:initech))
    paid(900, paid_on: Date.new(2026, 10, 5), client: clients(:globex), currency: "EUR")

    assert_equal [ [ "Initech", 400 ], [ "Globex Corporation", 100 ] ],
      Dashboard.new(@company).top_clients.map { [ it.client_name, it.amount ] }
    assert_equal [ "Initech" ], Dashboard.new(@company).top_clients(limit: 1).map(&:client_name)
  end

  test "lists overdue invoices in every currency, longest overdue first, whatever the filters" do
    older = create_invoice(100, status: "sent", issue_date: Date.new(2025, 1, 1), due_date: Date.new(2025, 1, 31), currency: "EUR")
    create_invoice(100, status: "sent", issue_date: Date.new(2026, 10, 1), due_date: Date.new(2026, 10, 20))

    assert_equal [ older, invoices(:globex_website) ], Dashboard.new(@company, period: "month", currency: "USD").overdue_invoices.to_a
  end

  test "lists sent invoices due within two weeks in every currency, soonest first" do
    today = create_invoice(100, status: "sent", issue_date: Date.new(2026, 10, 1), due_date: Date.new(2026, 10, 15))
    later = create_invoice(100, status: "sent", issue_date: Date.new(2026, 10, 1), due_date: Date.new(2026, 10, 29))
    create_invoice(100, status: "sent", issue_date: Date.new(2026, 10, 1), due_date: Date.new(2026, 10, 30))
    paid(100, issue_date: Date.new(2026, 10, 1), paid_on: Date.new(2026, 10, 2), due_date: Date.new(2026, 10, 20))
    euros = create_invoice(100, status: "sent", issue_date: Date.new(2026, 10, 1), due_date: Date.new(2026, 10, 20), currency: "EUR")

    assert_equal [ today, euros, later ], Dashboard.new(@company, currency: "USD").due_soon_invoices.to_a
  end

  test "only counts the company's own invoices" do
    paid(700, paid_on: Date.new(2026, 10, 3), company: companies(:other), client: clients(:other_company_client))

    assert_equal 0, Dashboard.new(@company).revenue.total
  end

  private
    def revenue_for(period)
      Dashboard.new(@company, period:).revenue.total
    end

    def paid(amount, paid_on:, issue_date: paid_on, **attributes)
      create_invoice(amount, status: "paid", issue_date:, paid_on:, **attributes)
    end

    def create_invoice(amount, company: @company, client: clients(:globex), currency: "USD", **attributes)
      company.invoices.create!(client:, currency:, **attributes,
        items_attributes: [ { description: "Work", quantity: 1, unit_price: amount } ])
    end
end
