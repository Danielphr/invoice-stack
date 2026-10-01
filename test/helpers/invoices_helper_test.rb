require "test_helper"

class InvoicesHelperTest < ActionView::TestCase
  test "formats money with the currency symbol, precision and code" do
    assert_equal "$1,200.50 USD", format_money(BigDecimal("1200.5"), "USD")
    assert_equal "R$950.00 BRL", format_money(950, "BRL")
    assert_equal "$U45,000.00 UYU", format_money(45_000, "UYU")
  end

  test "formats currencies without cents" do
    assert_equal "¥1,500 JPY", format_money(1500, "JPY")
  end

  test "does not repeat a code that is also the symbol" do
    assert_equal "CHF 80.00", format_money(80, "CHF")
  end

  test "shows overdue instead of the stored status" do
    invoice = invoices(:globex_website)
    invoice.due_date = Date.current - 1

    assert_dom_equal %(<span class="inline-flex rounded-md px-2 py-1 text-xs font-medium bg-red-50 text-red-700">Overdue</span>),
      invoice_status_badge(invoice)
  end

  test "labels item columns by billing type" do
    invoice = Invoice.new(billing_type: "hourly")

    assert_equal "Hours", quantity_label(invoice)
    assert_equal "Rate", unit_price_label(invoice)
  end
end
