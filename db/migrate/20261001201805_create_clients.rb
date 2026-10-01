class CreateClients < ActiveRecord::Migration[8.1]
  def change
    create_table :clients do |t|
      t.references :company, null: false, foreign_key: true, index: false
      t.string :name, null: false
      t.string :email
      t.string :phone
      t.string :website
      t.text :notes

      t.string :address_line1
      t.string :address_line2
      t.string :city, null: false
      t.string :state
      t.string :postal_code
      t.string :country, null: false

      t.string :contact_first_name
      t.string :contact_last_name
      t.string :contact_email
      t.string :contact_phone

      t.timestamps
    end

    # Client queries are always scoped to a company.
    add_index :clients, [ :company_id, :name ]
  end
end
