class Settings::PasswordsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :update, with: -> { redirect_to settings_path, alert: "Try again later." }

  def update
    @password_user = User.find(Current.user.id)
    @password_user.password_challenge = password_params[:password_challenge].to_s

    if @password_user.update(password_params.except(:password_challenge))
      Current.user.sessions.where.not(id: Current.session.id).destroy_all
      redirect_to settings_path, notice: "Password changed. You've been signed out on your other devices."
    else
      @user = Current.user
      render "settings/show", status: :unprocessable_entity
    end
  end

  private
    def password_params
      params.expect(user: [ :password_challenge, :password, :password_confirmation ])
    end
end
