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

  test "warns only when an existing invoice is no longer a draft" do
    invoice = invoices(:globex_website)
    assert_match "This invoice has been sent.", issued_invoice_warning(invoice)

    invoice.update!(status: "draft")
    assert_nil issued_invoice_warning(invoice)

    assert_nil issued_invoice_warning(Invoice.new(status: "sent"))
  end

  test "bases warnings on the saved status, not the one being edited" do
    invoice = invoices(:globex_website)
    invoice.status = "draft"

    assert_match "This invoice has been sent.", issued_invoice_warning(invoice)
  end

  test "asks for a stronger delete confirmation once an invoice is issued" do
    invoice = invoices(:globex_website)

    assert_equal "Invoice INV-001 has been sent. Deleting it removes it permanently and leaves a gap in your numbering. " \
      "Consider cancelling it instead.", delete_invoice_confirmation(invoice)

    invoice.status = "paid"
    assert_no_match "Consider cancelling", delete_invoice_confirmation(invoice)

    invoice.status = "draft"
    assert_equal "Delete invoice INV-001? This cannot be undone.", delete_invoice_confirmation(invoice)
  end

  test "labels item columns by billing type" do
    invoice = Invoice.new(billing_type: "hourly")

    assert_equal "Hours", quantity_label(invoice)
    assert_equal "Rate", unit_price_label(invoice)
  end
end
