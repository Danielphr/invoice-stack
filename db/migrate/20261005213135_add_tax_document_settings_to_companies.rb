class AddTaxDocumentSettingsToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :tax_documents_enabled, :boolean, null: false, default: false
    add_column :companies, :tax_document_name, :string
  end
end
