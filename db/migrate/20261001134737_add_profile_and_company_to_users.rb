class AddProfileAndCompanyToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :first_name, :string, null: false
    add_column :users, :last_name, :string, null: false
    add_reference :users, :company, null: false, foreign_key: true
  end
end
