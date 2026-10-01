class CreateInvoices < ActiveRecord::Migration[8.1]
  def change
    # Lets invoices reference a client together with its company, so the
    # database guarantees an invoice's client belongs to the same company.
    add_index :clients, [ :company_id, :id ], unique: true

    create_table :invoices do |t|
      t.references :company, null: false, foreign_key: true, index: false
      t.bigint :client_id, null: false
      t.string :number, null: false
      t.string :status, null: false, default: "draft"
      t.string :billing_type, null: false, default: "fixed"
      t.string :currency, null: false
      t.date :issue_date, null: false
      t.date :due_date
      t.decimal :discount, precision: 12, scale: 2, null: false, default: 0
      t.text :notes

      t.timestamps

      t.index [ :company_id, :number ], unique: true
      t.index [ :company_id, :client_id ]

      t.check_constraint "status IN ('draft', 'sent', 'paid', 'cancelled')", name: "invoices_status_check"
      t.check_constraint "billing_type IN ('fixed', 'hourly')", name: "invoices_billing_type_check"
      t.check_constraint "discount >= 0", name: "invoices_discount_check"
      t.check_constraint "due_date IS NULL OR due_date >= issue_date", name: "invoices_due_date_check"
    end

    add_foreign_key :invoices, :clients, column: [ :company_id, :client_id ], primary_key: [ :company_id, :id ]
  end
end
