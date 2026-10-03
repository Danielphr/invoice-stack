class CompaniesController < ApplicationController
  before_action :set_company

  def show
    @next_invoice_number = @company.preview_invoice_number(Date.current)
  end

  def edit
    @next_invoice_number = @company.preview_invoice_number(Date.current)
  end

  def update
    if @company.update(company_params)
      redirect_to company_path, notice: "Company updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_company
      @company = Current.user.company
    end

    def company_params
      params.expect(company: [
        :name, :email,
        :address_line1, :address_line2, :city, :state, :postal_code, :country,
        :time_zone, :default_currency,
        :logo, :accent_color,
        :invoice_number_pattern, :invoice_number_digits, :next_invoice_number
      ])
    end
end
