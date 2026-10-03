class SettingsController < ApplicationController
  def show
    @user = @password_user = Current.user
  end
end
