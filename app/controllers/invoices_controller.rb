class InvoicesController < ApplicationController
  before_action :set_invoice, only: %i[ show destroy ]

  def index
    @invoices = Current.user.company.invoices.includes(:client, :items).order(issue_date: :desc, id: :desc)
  end

  def show
  end

  def destroy
    @invoice.destroy!
    redirect_to invoices_path, notice: "Invoice deleted.", status: :see_other
  end

  private
    def set_invoice
      @invoice = Current.user.company.invoices.includes(:client, :items).find(params.expect(:id))
    end
end
