require "test_helper"

class InvoicePdfTest < ActiveSupport::TestCase
  setup do
    @invoice = invoices(:globex_website)
  end

  test "includes the company, client, items and totals" do
    text = pdf_text(@invoice)

    assert_includes text, "Acme Inc."
    assert_includes text, "INV-001"
    assert_includes text, "Globex Corporation"
    assert_includes text, "742 Evergreen Terrace"
    assert_includes text, "Website design"
    assert_includes text, "$2,200.00 USD"
    assert_includes text, "-$50.00 USD"
    assert_includes text, "$2,150.00 USD"
  end

  test "labels item columns by billing type" do
    assert_includes pdf_text(@invoice), "Quantity"

    @invoice.billing_type = "hourly"
    text = pdf_text(@invoice)

    assert_includes text, "Hours"
    assert_includes text, "Rate"
  end

  test "shows the payment date of a paid invoice" do
    @invoice.update!(status: "paid", paid_on: Date.new(2026, 9, 20))

    assert_includes pdf_text(@invoice), "Paid on: Sep 20, 2026"
  end

  test "renders characters outside Western European alphabets" do
    @invoice.client.update!(name: "Łódź Sp. z o.o.")

    assert_includes pdf_text(@invoice), "Łódź Sp. z o.o."
  end

  test "continues long invoices on another page, repeating the item header" do
    40.times { |index| @invoice.items.build(description: "Extra item #{index}", quantity: 1, unit_price: 10) }
    @invoice.update!(billing_type: "hourly")

    reader = PDF::Reader.new(StringIO.new(InvoicePdf.new(@invoice).render))
    second_page = reader.pages.second.text

    assert_equal 2, reader.page_count
    assert_includes second_page, "Page 2 of 2"
    assert_match(/Description\s+Hours\s+Rate\s+Amount/, second_page)
  end

  test "builds a file name that is safe on any system" do
    @invoice.number = "INV/2026: 7"

    assert_equal "INV-2026-7.pdf", InvoicePdf.new(@invoice).filename
  end

  private
    def pdf_text(invoice)
      PDF::Reader.new(StringIO.new(InvoicePdf.new(invoice).render)).pages.map(&:text).join("\n")
    end
end
