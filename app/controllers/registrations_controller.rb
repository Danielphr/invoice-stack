class RegistrationsController < ApplicationController
  layout "auth"

  allow_unauthenticated_access
  before_action :require_open_sign_ups
  rate_limit to: 10, within: 1.hour, only: :create, with: -> { redirect_to new_registration_path, alert: "Try again later." }

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    @user.company = Company.new

    if @user.save
      start_new_session_for @user
      redirect_to onboarding_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def require_open_sign_ups
      redirect_to new_session_path, alert: "Sign-up is closed." unless Rails.configuration.x.sign_ups_enabled
    end

    def user_params
      params.expect(user: [
        :first_name,
        :last_name,
        :email_address,
        :password,
        :password_confirmation
      ])
    end
end
