class AddDefaultInvoiceNotesToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :default_invoice_notes, :text
  end
end
