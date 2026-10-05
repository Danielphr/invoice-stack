require "test_helper"

class Invoices::ArchivesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @invoice = invoices(:globex_website)
    sign_in_as users(:one)
  end

  test "should require authentication" do
    sign_out

    post invoice_archive_url(@invoice)

    assert_redirected_to new_session_url
  end

  test "should archive a paid invoice" do
    @invoice.update!(status: "paid")

    post invoice_archive_url(@invoice)

    assert_redirected_to invoice_url(@invoice)
    assert @invoice.reload.archived?
  end

  test "should not archive an invoice that is still open" do
    post invoice_archive_url(@invoice)

    assert_redirected_to invoice_url(@invoice)
    assert_equal "Only paid or cancelled invoices can be archived", flash[:alert]
    assert_not @invoice.reload.archived?
  end

  test "should unarchive an invoice" do
    @invoice.update!(status: "paid")
    @invoice.archive

    delete invoice_archive_url(@invoice)

    assert_redirected_to invoice_url(@invoice)
    assert_not @invoice.reload.archived?
  end

  test "should not archive another company's invoice" do
    other_invoice = invoices(:other_company_invoice)
    other_invoice.update!(status: "paid")

    post invoice_archive_url(other_invoice)

    assert_response :not_found
    assert_not other_invoice.reload.archived?
  end
end
