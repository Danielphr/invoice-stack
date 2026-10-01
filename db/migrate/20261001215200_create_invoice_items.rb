class CreateInvoiceItems < ActiveRecord::Migration[8.1]
  def change
    create_table :invoice_items do |t|
      t.references :invoice, null: false, foreign_key: { on_delete: :cascade }
      t.string :description, null: false
      t.decimal :quantity, precision: 10, scale: 2, null: false
      t.decimal :unit_price, precision: 12, scale: 2, null: false
      t.integer :position, null: false, default: 0

      t.timestamps

      t.check_constraint "quantity > 0", name: "invoice_items_quantity_check"
      t.check_constraint "unit_price >= 0", name: "invoice_items_unit_price_check"
    end
  end
end
