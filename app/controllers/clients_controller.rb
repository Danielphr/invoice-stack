class ClientsController < ApplicationController
  before_action :set_client, only: %i[ show edit update destroy ]

  def index
    @clients = Current.user.company.clients.order(Client.arel_table[:name].lower)
  end

  def show
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
    @client.destroy!
    redirect_to clients_path, notice: "Client deleted.", status: :see_other
  end

  private
    def set_client
      @client = Current.user.company.clients.find(params.expect(:id))
    end

    def client_params
      params.expect(client: [
        :name, :email, :phone, :website, :notes,
        :address_line1, :address_line2, :city, :state, :postal_code, :country,
        :contact_first_name, :contact_last_name, :contact_email, :contact_phone
      ])
    end
end
