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

    assert_nil issued_invoice_warning(invoices(:globex_draft))

    assert_nil issued_invoice_warning(Invoice.new(status: "sent"))
  end

  test "bases warnings on the saved status, not the one being edited" do
    invoice = invoices(:globex_website)
    invoice.status = "draft"

    assert_match "This invoice has been sent.", issued_invoice_warning(invoice)
  end

  test "confirms sending with the number and, when it changes, the date" do
    draft = invoices(:globex_draft)

    travel_to Date.new(2026, 10, 3) do
      assert_equal "Send this invoice as INV-2? It will be dated October 3, 2026. " \
        "Its number is final: it can be cancelled, but not deleted or turned back into a draft.", send_invoice_confirmation(draft)

      draft.issue_date = Date.new(2026, 10, 3)
      assert_equal "Send this invoice as INV-2? " \
        "Its number is final: it can be cancelled, but not deleted or turned back into a draft.", send_invoice_confirmation(draft)
    end
  end

  test "titles an invoice by its number, or as a draft" do
    assert_equal "Invoice INV-001", invoice_title(invoices(:globex_website))
    assert_equal "Draft invoice", invoice_title(invoices(:globex_draft))
  end

  test "labels item columns by billing type" do
    invoice = Invoice.new(billing_type: "hourly")

    assert_equal "Hours", quantity_label(invoice)
    assert_equal "Rate", unit_price_label(invoice)
  end

  test "offers only the statuses an invoice can move to" do
    invoice = invoices(:globex_website)
    assert_equal %w[ sent paid cancelled ], invoice_status_options(invoice).map(&:last)

    invoice.update!(status: "paid")
    assert_equal %w[ sent paid ], invoice_status_options(invoice).map(&:last)

    invoice.update!(status: "sent")
    invoice.update!(status: "cancelled")
    assert_equal %w[ sent cancelled ], invoice_status_options(invoice).map(&:last)
  end

  test "describes each kind of invoice event" do
    event = ->(action, **attributes) { InvoiceEvent.new(invoice: invoices(:globex_website), action:, **attributes) }

    assert_equal "Created as a draft", invoice_event_description(event.("created", to_status: "draft"))
    assert_equal "Created as paid", invoice_event_description(event.("created", to_status: "paid"))
    assert_equal "Sent", invoice_event_description(event.("status_changed", from_status: "draft", to_status: "sent"))
    assert_equal "Marked as paid", invoice_event_description(event.("status_changed", from_status: "sent", to_status: "paid"))
    assert_equal "Cancelled", invoice_event_description(event.("status_changed", from_status: "sent", to_status: "cancelled"))
    assert_equal "Reopened", invoice_event_description(event.("status_changed", from_status: "paid", to_status: "sent"))
    assert_equal "Edited the due date, payment date, and items",
      invoice_event_description(event.("edited", fields: %w[ due_date paid_on items ]))
    assert_equal "Edited the Tax document number", invoice_event_description(event.("edited", fields: %w[ tax_document_number ]))
    assert_equal "Archived", invoice_event_description(event.("archived"))
    assert_equal "Unarchived", invoice_event_description(event.("unarchived"))
  end
end
