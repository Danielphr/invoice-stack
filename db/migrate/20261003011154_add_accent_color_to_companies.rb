class AddAccentColorToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :accent_color, :string, null: false, default: "#000000"
    add_check_constraint :companies, "accent_color ~ '^#[0-9a-f]{6}$'", name: "companies_accent_color_check"
  end
end
