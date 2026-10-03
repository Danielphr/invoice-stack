class AddDetailsAndPreferencesToCompanies < ActiveRecord::Migration[8.1]
  def change
    change_table :companies, bulk: true do |t|
      t.string :email
      t.string :address_line1
      t.string :address_line2
      t.string :city
      t.string :state
      t.string :postal_code
      t.string :country
      t.string :time_zone, null: false, default: "UTC"
      t.string :default_currency, null: false, default: "USD"
    end

    up_only do
      execute "UPDATE companies SET time_zone = 'Montevideo'"
    end
  end
end
