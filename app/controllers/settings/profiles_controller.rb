class Settings::ProfilesController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :update, with: -> { redirect_to settings_path, alert: "Try again later." }

  def update
    # A copy of the signed-in user, so the sidebar keeps showing the saved name if validation fails.
    @user = User.find(Current.user.id)
    @user.assign_attributes(profile_params.except(:password_challenge))
    # The email is how an account is recovered, so changing it needs the current password.
    @user.password_challenge = profile_params[:password_challenge].to_s if @user.email_address_changed?

    if @user.save
      redirect_to settings_path, notice: "Profile updated."
    else
      render "settings/show", status: :unprocessable_entity
    end
  end

  private
    def profile_params
      params.expect(user: [ :first_name, :last_name, :email_address, :password_challenge ])
    end
end
