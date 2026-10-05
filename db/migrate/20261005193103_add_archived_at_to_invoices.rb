class AddArchivedAtToInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :invoices, :archived_at, :datetime
    add_check_constraint :invoices, "archived_at IS NULL OR status IN ('paid', 'cancelled')", name: "invoices_archived_status_check"
  end
end
