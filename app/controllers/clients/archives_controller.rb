class Clients::ArchivesController < ApplicationController
  before_action :set_client

  def create
    @client.archive
    redirect_to @client, notice: "#{@client.name} archived."
  end

  def destroy
    @client.unarchive
    redirect_to @client, notice: "#{@client.name} unarchived."
  end

  private
    def set_client
      @client = Current.user.company.clients.find(params.expect(:client_id))
    end
end
