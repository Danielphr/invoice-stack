class AddSequenceToInvoices < ActiveRecord::Migration[8.1]
  def up
    add_column :invoices, :sequence, :integer

    execute <<~SQL
      UPDATE invoices SET sequence = numbered.sequence
      FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY company_id ORDER BY created_at, id) AS sequence FROM invoices
      ) numbered
      WHERE invoices.id = numbered.id
    SQL

    execute <<~SQL
      UPDATE companies SET next_invoice_number = GREATEST(
        next_invoice_number,
        (SELECT COALESCE(MAX(sequence), 0) + 1 FROM invoices WHERE invoices.company_id = companies.id)
      )
    SQL

    change_column_null :invoices, :sequence, false
    add_index :invoices, %i[ company_id sequence ], unique: true
    add_check_constraint :invoices, "sequence > 0", name: "invoices_sequence_check"
  end

  def down
    remove_column :invoices, :sequence
  end
end
