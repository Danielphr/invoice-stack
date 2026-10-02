class Invoices::StatusesController < ApplicationController
  def update
    invoice = Current.user.company.invoices.find(params.expect(:invoice_id))

    if invoice.update(status: params.expect(:status))
      redirect_to invoice, notice: "Invoice marked as #{invoice.status}."
    else
      redirect_to invoice, alert: "The status couldn't be changed: #{invoice.errors.full_messages.to_sentence}."
    end
  end
end
