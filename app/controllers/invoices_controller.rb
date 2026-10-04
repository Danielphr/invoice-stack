class InvoicesController < ApplicationController
  before_action :set_invoice, only: %i[ show edit update destroy ]
  before_action :set_clients, only: %i[ new create edit update ]
  helper_method :sort_column, :sort_direction

  def index
    invoices = Current.user.company.invoices.includes(:client, :items).sorted_by(sort_column, sort_direction)
    @pagy, @invoices = pagy(:offset, invoices, limit: 10, raise_range_error: true)
  rescue Pagy::RangeError => error
    redirect_to error.pagy.page_url(:last)
  end

  def show
    respond_to do |format|
      format.html
      format.pdf do
        pdf = InvoicePdf.new(@invoice)
        send_data pdf.render, filename: pdf.filename, type: :pdf, disposition: :inline
      end
    end
  end

  def new
    company = Current.user.company
    client = company.clients.find_by(id: params[:client_id])
    @invoice = company.invoices.new(client:, issue_date: Date.current, currency: company.default_currency, notes: company.default_invoice_notes)
    @invoice.items.build
  end

  def create
    @invoice = Current.user.company.invoices.new(invoice_params)

    if @invoice.save
      redirect_to @invoice, notice: "Invoice created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @invoice.update(invoice_params)
      redirect_to @invoice, notice: "Invoice updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @invoice.destroy
      redirect_to invoices_path, notice: "Draft deleted.", status: :see_other
    else
      redirect_to @invoice, alert: @invoice.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private
    def sort_column
      params[:sort].presence_in(Invoice::SORTS) || "number"
    end

    def sort_direction
      params[:direction].presence_in(%w[ asc desc ]) || "desc"
    end

    def set_invoice
      @invoice = Current.user.company.invoices.includes(:client, :items).find(params.expect(:id))
    end

    def set_clients
      @clients = Current.user.company.clients.by_name
    end

    def invoice_params
      params.expect(invoice: [
        :client_id, :status, :billing_type, :currency, :issue_date, :due_date, :paid_on, :discount, :notes,
        items_attributes: [ [ :id, :description, :quantity, :unit_price, :_destroy ] ]
      ])
    end
end
