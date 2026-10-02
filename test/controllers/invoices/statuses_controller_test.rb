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
    assert_equal Date.current, @invoice.paid_on

    follow_redirect!
    assert_select "[role=status]", "Invoice marked as paid."
  end

  test "should mark a draft as sent" do
    @invoice.update!(status: "draft")

    patch invoice_status_url(@invoice), params: { status: "sent" }

    assert @invoice.reload.sent?
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
    assert other_invoice.reload.draft?
  end

  test "should offer the next actions for each status" do
    { "draft" => [ "Mark as sent" ], "sent" => [ "Mark as paid", "Cancel invoice" ],
      "paid" => [ "Reopen" ], "cancelled" => [ "Reopen" ] }.each do |status, actions|
      @invoice.update!(status: status)

      get invoice_url(@invoice)

      assert_equal actions, css_select("form[action='#{invoice_status_path(@invoice)}'] button").map(&:text),
        "unexpected actions for a #{status} invoice"
    end
  end
end
