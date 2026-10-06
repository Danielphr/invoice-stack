require "application_system_test_case"

class TaxDocumentsTest < ApplicationSystemTestCase
  setup do
    companies(:one).update!(tax_documents_enabled: true, tax_document_name: "Factura")
    @invoice = invoices(:globex_website)
    sign_in_as users(:one)
  end

  test "adds a tax document from the invoice list" do
    visit invoices_path

    click_on "Pending"
    within "dialog[open]" do
      assert_text "Invoice #{@invoice.number}"
      fill_in "Number", with: "A-123"
      attach_file "PDF", file_fixture("tax-document.pdf")
      click_on "Save"
    end

    assert_text "Factura saved."
    assert_current_path invoices_path
    assert_selector "tbody button", text: "A-123"
    assert_link href: invoice_tax_document_path(@invoice)
    assert @invoice.reload.tax_document.attached?
  end

  test "closes the form without saving" do
    visit invoices_path

    click_on "Pending"
    within "dialog[open]" do
      fill_in "Number", with: "A-123"
      click_on "Cancel"
    end

    assert_no_selector "dialog[open]"
    assert_nil @invoice.reload.tax_document_number
  end
end
