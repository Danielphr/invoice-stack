class Invoice < ApplicationRecord
  belongs_to :company
  belongs_to :client
  has_many :items, -> { order(:position) }, class_name: "InvoiceItem", dependent: :destroy, inverse_of: :invoice

  accepts_nested_attributes_for :items, allow_destroy: true

  enum :status, %w[ draft sent paid cancelled ].index_by(&:itself), default: "draft", validate: true
  enum :billing_type, %w[ fixed hourly ].index_by(&:itself), default: "fixed", validate: true

  normalizes :number, with: ->(number) { number.strip.presence }
  normalizes :notes, with: ->(notes) { notes.strip.presence }

  before_validation :position_items
  before_create :assign_number, if: -> { number.blank? }

  # A new invoice without a number gets the company's next one when it is saved.
  validates :number, presence: true, on: :update
  validates :number, length: { maximum: 50 }, uniqueness: { scope: :company_id }, allow_blank: true
  validates :issue_date, presence: true
  validates :currency, inclusion: { in: Currency.codes }
  validates :discount, numericality: { greater_than_or_equal_to: 0, less_than: 10_000_000_000 }
  validates :notes, length: { maximum: 500 }
  validate :client_must_belong_to_company
  validate :due_date_cannot_be_before_issue_date
  validate :must_have_items
  validate :discount_cannot_exceed_subtotal

  def subtotal
    active_items.sum(&:amount)
  end

  def total
    subtotal - discount.to_d
  end

  def overdue?
    sent? && due_date.present? && due_date < Date.current
  end

  private
    def active_items
      items.reject(&:marked_for_destruction?)
    end

    def position_items
      active_items.each_with_index { |item, index| item.position = index }
    end

    def assign_number
      self.number = company.reserve_invoice_number(issue_date)
    end

    def client_must_belong_to_company
      errors.add(:client, :invalid) if client && client.company_id != company_id
    end

    def due_date_cannot_be_before_issue_date
      return unless issue_date && due_date

      errors.add(:due_date, "can't be before the issue date") if due_date < issue_date
    end

    def must_have_items
      errors.add(:base, "Add at least one item") if active_items.empty?
    end

    def discount_cannot_exceed_subtotal
      return unless discount && active_items.all? { it.quantity && it.unit_price }

      errors.add(:discount, "can't be greater than the subtotal") if discount > subtotal
    end
end
