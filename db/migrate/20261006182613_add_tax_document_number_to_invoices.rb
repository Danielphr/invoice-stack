class AddTaxDocumentNumberToInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :invoices, :tax_document_number, :string
    add_index :invoices, [ :company_id, :tax_document_number ], unique: true, where: "tax_document_number IS NOT NULL"
  end
end
