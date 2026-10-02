class InvoicesController < ApplicationController
  before_action :set_invoice, only: %i[ show edit update destroy ]
  before_action :set_clients, only: %i[ new create edit update ]

  def index
    @invoices = Current.user.company.invoices.includes(:client, :items).order(issue_date: :desc, id: :desc)
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
    @invoice = Current.user.company.invoices.new(issue_date: Date.current, currency: Current.user.company.default_currency)
    @invoice.items.build
    set_number_preview
  end

  def create
    @invoice = Current.user.company.invoices.new(invoice_params)

    if @invoice.save
      redirect_to @invoice, notice: "Invoice created."
    else
      set_number_preview
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    reject_duplicate_number(:new)
  end

  def edit
  end

  def update
    if @invoice.update(invoice_params)
      redirect_to @invoice, notice: "Invoice updated."
    else
      render :edit, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    reject_duplicate_number(:edit)
  end

  def destroy
    @invoice.destroy!
    redirect_to invoices_path, notice: "Invoice deleted.", status: :see_other
  end

  private
    def set_invoice
      @invoice = Current.user.company.invoices.includes(:client, :items).find(params.expect(:id))
    end

    def set_clients
      @clients = Current.user.company.clients.by_name
    end

    def set_number_preview
      @number_preview = Current.user.company.preview_invoice_number(@invoice.issue_date || Date.current)
    end

    # The uniqueness validation catches duplicates in normal use; the unique
    # index only fires when two requests save the same number at the same time.
    def reject_duplicate_number(template)
      @invoice.errors.add(:number, :taken)
      set_number_preview if @invoice.new_record?
      render template, status: :unprocessable_entity
    end

    def invoice_params
      params.expect(invoice: [
        :client_id, :number, :status, :billing_type, :currency, :issue_date, :due_date, :paid_on, :discount, :notes,
        items_attributes: [ [ :id, :description, :quantity, :unit_price, :_destroy ] ]
      ])
    end
end
