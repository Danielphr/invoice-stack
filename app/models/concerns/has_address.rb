module HasAddress
  extend ActiveSupport::Concern

  included do
    normalizes :address_line1, :address_line2, :city, :state, :postal_code, with: ->(value) { value.strip.presence }

    validates :address_line1, :address_line2, :city, :state, length: { maximum: 100 }
    validates :postal_code, length: { maximum: 20 }
    validates :country, inclusion: { in: Country.codes }, allow_blank: true
  end

  def country_name
    Country.name_for(country)
  end

  def address_lines
    [
      address_line1,
      address_line2,
      [ city, state, postal_code ].compact.join(", "),
      country_name
    ].compact_blank
  end
end
