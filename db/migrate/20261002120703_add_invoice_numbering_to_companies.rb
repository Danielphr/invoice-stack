class AddInvoiceNumberingToCompanies < ActiveRecord::Migration[8.1]
  def change
    change_table :companies, bulk: true do |t|
      t.string :invoice_number_pattern, null: false, default: "INV-{NUMBER}"
      t.integer :invoice_number_digits, null: false, default: 1
      t.integer :next_invoice_number, null: false, default: 1

      t.check_constraint "position('{NUMBER}' in invoice_number_pattern) > 0", name: "companies_invoice_number_pattern_check"
      t.check_constraint "invoice_number_digits BETWEEN 1 AND 10", name: "companies_invoice_number_digits_check"
      t.check_constraint "next_invoice_number >= 1", name: "companies_next_invoice_number_check"
    end
  end
end
