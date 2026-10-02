class Company < ApplicationRecord
  INVOICE_NUMBER_TAG = /\{(NUMBER|YEAR|MONTH)\}/
  # Characters that would break file names when invoices are exported.
  INVOICE_NUMBER_FORBIDDEN_CHARACTERS = %r{[\s/\\<>:"|?*]}

  has_many :users, dependent: :destroy
  # Invoices are declared before clients so they are destroyed first.
  # A client that still has invoices cannot be destroyed.
  has_many :invoices, dependent: :destroy
  has_many :clients, dependent: :destroy

  normalizes :invoice_number_pattern, with: ->(pattern) { pattern.strip }

  validates :name, presence: true, on: :update
  validates :invoice_number_pattern, presence: true, length: { maximum: 30 }
  validates :invoice_number_digits, numericality: { only_integer: true, in: 1..10 }
  validates :next_invoice_number, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than: 1_000_000_000 }
  validate :invoice_number_pattern_must_be_valid

  def onboarding_complete?
    name.present?
  end

  # Builds an invoice number from the pattern, e.g. "INV-{YEAR}-{NUMBER}"
  # with sequence 42 and 4 digits becomes "INV-2026-0042".
  def format_invoice_number(sequence, date)
    invoice_number_pattern.gsub(INVOICE_NUMBER_TAG) do |tag|
      case tag
      when "{NUMBER}" then sequence.to_s.rjust(invoice_number_digits, "0")
      when "{YEAR}" then date.year.to_s
      when "{MONTH}" then format("%02d", date.month)
      end
    end
  end

  # Takes the next free invoice number and advances the counter. Must run inside
  # the transaction that creates the invoice: the row lock makes concurrent
  # requests wait, so two invoices can never be given the same number.
  def reserve_invoice_number(date)
    lock!
    sequence = next_free_invoice_sequence(date)
    update_columns(next_invoice_number: sequence + 1)
    format_invoice_number(sequence, date)
  end

  # The number the next invoice would get, for display only; nothing is reserved.
  def preview_invoice_number(date)
    format_invoice_number(next_free_invoice_sequence(date), date)
  end

  private
    # Skips numbers that were already used, e.g. typed in manually.
    def next_free_invoice_sequence(date)
      sequence = next_invoice_number
      sequence += 1 while invoices.exists?(number: format_invoice_number(sequence, date))
      sequence
    end

    def invoice_number_pattern_must_be_valid
      return if invoice_number_pattern.blank?

      if invoice_number_pattern.scan("{NUMBER}").size != 1
        errors.add(:invoice_number_pattern, "must contain {NUMBER} exactly once")
      end

      if invoice_number_pattern.gsub(INVOICE_NUMBER_TAG, "").match?(/[{}]/)
        errors.add(:invoice_number_pattern, "can only use the tags {NUMBER}, {YEAR} and {MONTH}")
      end

      if invoice_number_pattern.match?(INVOICE_NUMBER_FORBIDDEN_CHARACTERS)
        errors.add(:invoice_number_pattern, %(can't contain spaces or any of / \\ < > : " | ? *))
      end
    end
end
