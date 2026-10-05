class Invoices::ArchivesController < ApplicationController
  before_action :set_invoice

  def create
    if @invoice.archive
      redirect_to @invoice, notice: "Invoice #{@invoice.number} archived."
    else
      redirect_to @invoice, alert: @invoice.errors.full_messages.to_sentence
    end
  end

  def destroy
    if @invoice.unarchive
      redirect_to @invoice, notice: "Invoice #{@invoice.number} unarchived."
    else
      redirect_to @invoice, alert: @invoice.errors.full_messages.to_sentence
    end
  end

  private
    def set_invoice
      @invoice = Current.user.company.invoices.find(params.expect(:invoice_id))
    end
end
