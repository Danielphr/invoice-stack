class DashboardController < ApplicationController
  def index
    @dashboard = Dashboard.new(Current.user.company, period: params[:period], currency: params[:currency])
  end
end
