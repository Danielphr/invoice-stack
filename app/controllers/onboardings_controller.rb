class OnboardingsController < ApplicationController
  layout "auth"

  skip_before_action :require_completed_onboarding
  before_action :redirect_if_completed

  def show
    @company = Current.user.company
  end

  def update
    @company = Current.user.company

    if @company.update(company_params)
      redirect_to root_path
    else
      render :show, status: :unprocessable_entity
    end
  end

  private
    def company_params
      params.expect(company: [ :name ])
    end

    def redirect_if_completed
      redirect_to root_path if Current.user.company.onboarding_complete?
    end
end
