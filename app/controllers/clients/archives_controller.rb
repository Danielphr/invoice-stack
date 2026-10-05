class Clients::ArchivesController < ApplicationController
  before_action :set_client

  def create
    if @client.archive
      redirect_to @client, notice: "#{@client.name} archived."
    else
      redirect_to @client, alert: @client.errors.full_messages.to_sentence
    end
  end

  def destroy
    if @client.unarchive
      redirect_to @client, notice: "#{@client.name} unarchived."
    else
      redirect_to @client, alert: @client.errors.full_messages.to_sentence
    end
  end

  private
    def set_client
      @client = Current.user.company.clients.find(params.expect(:client_id))
    end
end
