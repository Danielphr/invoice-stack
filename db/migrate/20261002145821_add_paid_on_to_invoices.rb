class AddPaidOnToInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :invoices, :paid_on, :date

    up_only do
      execute "UPDATE invoices SET paid_on = updated_at::date WHERE status = 'paid'"
    end

    add_check_constraint :invoices, "(status = 'paid') = (paid_on IS NOT NULL)", name: "invoices_paid_on_check"
  end
end
