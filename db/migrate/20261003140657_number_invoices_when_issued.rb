class NumberInvoicesWhenIssued < ActiveRecord::Migration[8.1]
  def up
    change_column_null :invoices, :number, true
    change_column_null :invoices, :sequence, true

    execute "UPDATE invoices SET number = NULL, sequence = NULL WHERE status = 'draft'"

    add_check_constraint :invoices, "(status = 'draft') = (number IS NULL)", name: "invoices_number_check"
    add_check_constraint :invoices, "(number IS NULL) = (sequence IS NULL)", name: "invoices_number_sequence_check"
  end

  # Drafts lose their numbers on the way up, so there is nothing to restore them from.
  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
