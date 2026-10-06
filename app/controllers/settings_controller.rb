class SettingsController < ApplicationController
  before_action :set_company

  def show
    @next_invoice_number = @company.preview_invoice_number(Date.current)
  end

  def update
    if @company.update(settings_params)
      redirect_to settings_path, notice: "Settings saved."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private
    def set_company
      @company = Current.user.company
    end

    def settings_params
      params.expect(company: [
        :time_zone, :default_currency,
        :invoice_number_pattern, :invoice_number_digits, :next_invoice_number,
        :default_invoice_notes,
        :tax_documents_enabled, :tax_document_name
      ])
    end
end
