class ClientsController < ApplicationController
  before_action :set_client, only: %i[ show edit update destroy ]
  before_action :require_active_client, only: %i[ edit update ]
  helper_method :sort_column, :sort_direction

  def index
    @archived = params[:show] == "archived"
    clients = Current.user.company.clients
    @any_archived = @archived || clients.archived.exists?
    clients = (@archived ? clients.archived : clients.active).sorted_by(sort_column, sort_direction)
    @pagy, @clients = pagy(:offset, clients, limit: 10, raise_range_error: true)
    @stats = Client.invoice_stats(@clients)
  rescue Pagy::RangeError => error
    redirect_to error.pagy.page_url(:last)
  end

  def show
    @summary = @client.invoice_summary
    @pagy, @invoices = pagy(:offset, @client.invoices.includes(:items).sorted_by("number", "desc"), limit: 10, raise_range_error: true)
  rescue Pagy::RangeError => error
    redirect_to error.pagy.page_url(:last)
  end

  def new
    @client = Current.user.company.clients.new
  end

  def create
    @client = Current.user.company.clients.new(client_params)

    if @client.save
      redirect_to @client, notice: "Client created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @client.update(client_params)
      redirect_to @client, notice: "Client updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @client.destroy
      redirect_to clients_path, notice: "Client deleted.", status: :see_other
    else
      redirect_to @client, alert: "This client has invoices and can't be deleted.", status: :see_other
    end
  end

  private
    def sort_column
      params[:sort].presence_in(Client::SORTS) || "name"
    end

    def sort_direction
      params[:direction].presence_in(%w[ asc desc ]) || "asc"
    end

    def set_client
      @client = Current.user.company.clients.find(params.expect(:id))
    end

    def require_active_client
      redirect_to @client, alert: "Unarchive this client to edit it." if @client.archived?
    end

    def client_params
      params.expect(client: [
        :name, :email, :phone, :website, :notes,
        :address_line1, :address_line2, :city, :state, :postal_code, :country,
        :contact_first_name, :contact_last_name, :contact_email, :contact_phone
      ])
    end
end
