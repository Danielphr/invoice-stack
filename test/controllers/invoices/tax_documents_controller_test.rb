require "test_helper"

class Invoices::TaxDocumentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @company = companies(:one)
    @company.update!(tax_documents_enabled: true, tax_document_name: "Factura")
    @invoice = invoices(:globex_website)
    sign_in_as users(:one)
  end

  test "should require authentication" do
    sign_out

    patch invoice_tax_document_url(@invoice), params: { invoice: { tax_document_number: "A-1" } }

    assert_redirected_to new_session_url
    assert_nil @invoice.reload.tax_document_number
  end

  test "should save the number and PDF" do
    patch invoice_tax_document_url(@invoice), params: { invoice: {
      tax_document_number: "A-1", tax_document: fixture_file_upload("tax-document.pdf", "application/pdf")
    } }

    assert_redirected_to invoice_url(@invoice)
    assert_equal "Factura saved.", flash[:notice]
    @invoice.reload
    assert_equal "A-1", @invoice.tax_document_number
    assert @invoice.tax_document.attached?
  end

  test "should return to the list it was saved from" do
    patch invoice_tax_document_url(@invoice), params: { invoice: { tax_document_number: "A-1" } },
      headers: { "Referer" => invoices_url(sort: "total", page: 1) }

    assert_redirected_to invoices_url(sort: "total", page: 1)
  end

  test "should reopen the form with the errors when the number is missing" do
    patch invoice_tax_document_url(@invoice), params: { invoice: { tax_document_number: "" } }

    assert_response :unprocessable_entity
    assert_select "section[data-dialog-open-value=true] [role=alert] li", "Factura number is required"
  end

  test "should only accept PDFs" do
    patch invoice_tax_document_url(@invoice), params: { invoice: {
      tax_document_number: "A-1", tax_document: fixture_file_upload("logo.png", "image/png")
    } }

    assert_response :unprocessable_entity
    assert_select "[role=alert] li", "Factura must be a PDF"
    assert_not @invoice.reload.tax_document.attached?
  end

  test "should serve the PDF only through the app" do
    @invoice.update!(tax_document_number: "A-1", tax_document: fixture_file_upload("tax-document.pdf", "application/pdf"))

    get invoice_tax_document_url(@invoice)

    assert_response :success
    assert_equal "application/pdf", response.media_type

    sign_out
    get invoice_tax_document_url(@invoice)
    assert_redirected_to new_session_url
  end

  test "should remove the number and PDF" do
    @invoice.update!(tax_document_number: "A-1", tax_document: fixture_file_upload("tax-document.pdf", "application/pdf"))

    delete invoice_tax_document_url(@invoice)

    assert_redirected_to invoice_url(@invoice)
    @invoice.reload
    assert_nil @invoice.tax_document_number
    assert_not @invoice.tax_document.attached?
  end

  test "should not change an archived invoice" do
    @invoice.update!(status: "paid")
    @invoice.archive

    patch invoice_tax_document_url(@invoice), params: { invoice: { tax_document_number: "A-1" } }

    assert_redirected_to invoice_url(@invoice)
    assert_nil @invoice.reload.tax_document_number
  end

  test "should not be available when tax documents are turned off" do
    @company.update!(tax_documents_enabled: false)

    patch invoice_tax_document_url(@invoice), params: { invoice: { tax_document_number: "A-1" } }

    assert_response :not_found
  end

  test "should not touch another company's invoice" do
    other_invoice = invoices(:other_company_invoice)

    patch invoice_tax_document_url(other_invoice), params: { invoice: { tax_document_number: "A-1" } }
    assert_response :not_found

    get invoice_tax_document_url(other_invoice)
    assert_response :not_found
  end
end
