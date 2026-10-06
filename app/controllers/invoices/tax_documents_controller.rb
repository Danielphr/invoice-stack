class Invoices::TaxDocumentsController < ApplicationController
  before_action :set_invoice
  before_action :require_tax_documents
  before_action :require_active_invoice, only: %i[ update destroy ]

  # Served through the app, not a public storage link, so only the company can open its tax documents.
  def show
    document = @invoice.tax_document
    return head :not_found unless document.attached?

    send_data document.download, filename: document.filename.to_s, type: "application/pdf", disposition: :inline
  end

  def update
    @invoice.assign_attributes(tax_document_params)

    if @invoice.save(context: :tax_document)
      redirect_to @invoice, notice: "#{@invoice.company.tax_document_label} saved."
    else
      @tax_document_form_open = true
      render "invoices/show", status: :unprocessable_entity
    end
  end

  def destroy
    if @invoice.update(tax_document_number: nil, tax_document: nil)
      redirect_to @invoice, notice: "#{@invoice.company.tax_document_label} removed.", status: :see_other
    else
      redirect_to @invoice, alert: @invoice.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private
    def set_invoice
      @invoice = Current.user.company.invoices.includes(:client, :items).find(params.expect(:invoice_id))
    end

    def require_tax_documents
      head :not_found unless @invoice.company.tax_documents_enabled?
    end

    def require_active_invoice
      redirect_to @invoice, alert: "Unarchive this invoice to change it." if @invoice.archived?
    end

    def tax_document_params
      params.expect(invoice: [ :tax_document_number, :tax_document ])
    end
end
