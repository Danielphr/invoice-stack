class InvoiceItem < ApplicationRecord
  belongs_to :invoice

  normalizes :description, with: ->(description) { description.strip.presence }

  validates :description, presence: true, length: { maximum: 255 }
  validates :quantity, numericality: { greater_than: 0, less_than: 100_000_000 }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0, less_than: 10_000_000_000 }

  def amount
    (quantity.to_d * unit_price.to_d).round(2)
  end
end
