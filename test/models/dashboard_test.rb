require "test_helper"

class DashboardTest < ActiveSupport::TestCase
  setup do
    @company = companies(:one)
    travel_to Date.new(2026, 10, 15)
  end

  test "counts revenue by payment date within the period, per currency" do
    paid(100, paid_on: Date.new(2026, 10, 3))
    paid(50, paid_on: Date.new(2026, 10, 10), currency: "EUR")
    paid(200, paid_on: Date.new(2026, 7, 1))
    paid(300, paid_on: Date.new(2025, 12, 20), issue_date: Date.new(2025, 12, 1))

    assert_equal({ "EUR" => 50, "USD" => 100 }, revenue_for("month"))
    assert_equal({ "EUR" => 50, "USD" => 100 }, revenue_for("quarter"))
    assert_equal({ "EUR" => 50, "USD" => 300 }, revenue_for("year"))
    assert_equal({ "USD" => 300 }, revenue_for("last_year"))
    assert_equal({ "EUR" => 50, "USD" => 600 }, revenue_for("all"))
  end

  test "counts a payment in the month it was received, not the month it was issued" do
    paid(100, issue_date: Date.new(2026, 9, 20), paid_on: Date.new(2026, 10, 2))

    assert_equal({ "USD" => 100 }, revenue_for("month"))
  end

  test "falls back to all time for an unknown period" do
    assert_equal "all", Dashboard.new(@company, period: "decade").period
  end

  test "summarizes outstanding and overdue invoices and counts drafts" do
    create_invoice(500, status: "sent", issue_date: Date.new(2026, 10, 1), due_date: Date.new(2026, 10, 30))
    dashboard = Dashboard.new(@company)

    assert_equal 2, dashboard.outstanding.count
    assert_equal({ "USD" => 2650 }, dashboard.outstanding.totals)
    assert_equal 1, dashboard.overdue.count
    assert_equal({ "USD" => 2150 }, dashboard.overdue.totals)
    assert_equal 1, dashboard.drafts_count
  end

  test "lists revenue for each of the last 12 months, including empty ones" do
    paid(100, paid_on: Date.new(2026, 10, 3))
    paid(50, paid_on: Date.new(2026, 10, 10), currency: "EUR")
    paid(300, paid_on: Date.new(2025, 11, 20), issue_date: Date.new(2025, 11, 1))
    paid(999, paid_on: Date.new(2025, 10, 31), issue_date: Date.new(2025, 10, 1))

    months = Dashboard.new(@company).revenue_by_month

    assert_equal 12, months.size
    assert_equal [ Date.new(2025, 11, 1), Date.new(2026, 10, 1) ], [ months.keys.first, months.keys.last ]
    assert_equal({ "USD" => 300 }, months[Date.new(2025, 11, 1)])
    assert_equal({ "EUR" => 50, "USD" => 100 }, months[Date.new(2026, 10, 1)])
    assert_equal({}, months[Date.new(2026, 5, 1)])
  end

  test "ranks the top clients within each currency" do
    paid(100, paid_on: Date.new(2026, 10, 3), client: clients(:globex))
    paid(400, paid_on: Date.new(2026, 10, 4), client: clients(:initech))
    paid(80, paid_on: Date.new(2026, 10, 5), client: clients(:globex), currency: "EUR")

    top = Dashboard.new(@company).top_clients(limit: 1)

    assert_equal [ [ "EUR", "Globex Corporation", 80 ], [ "USD", "Initech", 400 ] ],
      top.map { [ it.currency, it.client_name, it.amount ] }
  end

  test "lists the most recent payments first" do
    older = paid(100, paid_on: Date.new(2026, 9, 1))
    newer = paid(200, paid_on: Date.new(2026, 10, 1))

    assert_equal [ newer, older ], Dashboard.new(@company).recent_payments.to_a
  end

  test "only counts the company's own invoices" do
    paid(700, paid_on: Date.new(2026, 10, 3), company: companies(:other), client: clients(:other_company_client))

    assert_empty Dashboard.new(@company).revenue
  end

  private
    def revenue_for(period)
      Dashboard.new(@company, period:).revenue
    end

    def paid(amount, paid_on:, issue_date: paid_on, **attributes)
      create_invoice(amount, status: "paid", issue_date:, paid_on:, **attributes)
    end

    def create_invoice(amount, company: @company, client: clients(:globex), currency: "USD", **attributes)
      company.invoices.create!(client:, currency:, **attributes,
        items_attributes: [ { description: "Work", quantity: 1, unit_price: amount } ])
    end
end
