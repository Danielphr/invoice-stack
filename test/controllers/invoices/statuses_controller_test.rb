require "test_helper"

class Invoices::StatusesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @invoice = invoices(:globex_website)
    sign_in_as users(:one)
  end

  test "should mark a sent invoice as paid today" do
    patch invoice_status_url(@invoice), params: { status: "paid" }

    assert_redirected_to invoice_url(@invoice)
    @invoice.reload
    assert @invoice.paid?
    assert_equal Time.find_zone(@invoice.company.time_zone).today, @invoice.paid_on

    follow_redirect!
    assert_select "[role=status]", "Invoice INV-001 marked as paid."
  end

  test "should mark a draft as sent and give it the next number" do
    draft = invoices(:globex_draft)

    patch invoice_status_url(draft), params: { status: "sent" }

    assert draft.reload.sent?
    assert_equal "INV-2", draft.number
    follow_redirect!
    assert_select "[role=status]", "Invoice INV-2 marked as sent."
  end

  test "should confirm before sending a draft" do
    get invoice_url(invoices(:globex_draft))

    assert_select "form[action=?][data-turbo-confirm^=?][data-confirm-title=?]:not([data-confirm-destructive])",
      invoice_status_path(invoices(:globex_draft)), "Send this invoice as INV-2?", "Send invoice"
  end

  test "should cancel an invoice" do
    patch invoice_status_url(@invoice), params: { status: "cancelled" }

    assert @invoice.reload.cancelled?
  end

  test "should reopen a paid invoice and remove its payment date" do
    @invoice.update!(status: "paid")

    patch invoice_status_url(@invoice), params: { status: "sent" }

    @invoice.reload
    assert @invoice.sent?
    assert_nil @invoice.paid_on
  end

  test "should reject an unknown status" do
    patch invoice_status_url(@invoice), params: { status: "overdue" }

    assert_redirected_to invoice_url(@invoice)
    assert @invoice.reload.sent?

    follow_redirect!
    assert_select "[role=alert]", /Status is not included in the list/
  end

  test "should not change another company's invoice" do
    other_invoice = invoices(:other_company_invoice)

    patch invoice_status_url(other_invoice), params: { status: "paid" }

    assert_response :not_found
    assert other_invoice.reload.sent?
  end

  test "should offer the next actions for each status" do
    draft = invoices(:globex_draft)
    get invoice_url(draft)
    assert_equal [ "Mark as sent" ], css_select("form[action='#{invoice_status_path(draft)}'] button").map(&:text)

    { "sent" => [ "Mark as paid", "Cancel invoice" ], "paid" => [ "Reopen" ], "cancelled" => [ "Reopen" ] }.each do |status, actions|
      @invoice.update!(status: status)

      get invoice_url(@invoice)

      assert_equal actions, css_select("form[action='#{invoice_status_path(@invoice)}'] button").map(&:text),
        "unexpected actions for a #{status} invoice"
    end
  end
end
