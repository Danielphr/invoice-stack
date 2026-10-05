class CreateInvoiceEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :invoice_events do |t|
      t.references :invoice, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, foreign_key: { on_delete: :nullify }
      t.string :action, null: false
      t.string :from_status
      t.string :to_status
      t.string :fields, array: true, null: false, default: []
      t.datetime :created_at, null: false
    end

    add_check_constraint :invoice_events, "action IN ('created', 'status_changed', 'edited', 'archived', 'unarchived')",
      name: "invoice_events_action_check"
  end
end
