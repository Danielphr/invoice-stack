class Company < ApplicationRecord
  INVOICE_NUMBER_TAG = /\{(NUMBER|YEAR|MONTH)\}/
  # Characters that would break file names when invoices are exported.
  INVOICE_NUMBER_FORBIDDEN_CHARACTERS = %r{[\s/\\<>:"|?*]}
  LOGO_CONTENT_TYPES = %w[ image/png image/jpeg image/webp ].freeze
  LOGO_MAX_SIZE = 5.megabytes

  include HasAddress

  has_one_attached :logo do |attachable|
    attachable.variant :document, resize_to_limit: [ 600, 300 ], format: :png
  end

  has_many :users, dependent: :destroy
  # Invoices are declared before clients so they are destroyed first.
  # A client that still has invoices cannot be destroyed.
  has_many :invoices, dependent: :destroy
  has_many :clients, dependent: :destroy

  normalizes :invoice_number_pattern, with: ->(pattern) { pattern.strip }
  normalizes :email, with: ->(email) { email.strip.downcase.presence }
  normalizes :accent_color, with: ->(color) { color.strip.downcase }
  normalizes :default_invoice_notes, with: ->(notes) { notes.strip.presence }

  validates :name, presence: true, on: :update
  validates :name, length: { maximum: 100 }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, length: { maximum: 254 }, allow_nil: true
  validates :time_zone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }
  validates :default_currency, inclusion: { in: Currency.codes }
  validates :accent_color, format: { with: /\A#\h{6}\z/, message: "must be a hex color like #4f46e5" }
  validates :invoice_number_pattern, presence: true, length: { maximum: 30 }
  validates :default_invoice_notes, length: { maximum: 500 }
  validates :invoice_number_digits, numericality: { only_integer: true, in: 1..10 }
  validates :next_invoice_number, numericality: { only_integer: true, greater_than_or_equal_to: :lowest_next_invoice_number, less_than: 1_000_000_000 }
  validate :invoice_number_pattern_must_be_valid
  validate :logo_must_be_a_supported_image

  def onboarding_complete?
    name.present?
  end

  def address_complete?
    [ address_line1, city, country ].all?(&:present?)
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

  # Takes the next sequence and advances the counter. Must run inside the
  # transaction that creates the invoice: the row lock makes concurrent
  # requests wait, so two invoices can never be given the same sequence.
  def reserve_invoice_sequence
    lock!
    next_invoice_number.tap { update_columns(next_invoice_number: it + 1) }
  end

  def preview_invoice_number(date)
    format_invoice_number(next_invoice_number, date)
  end

  def lowest_next_invoice_number
    (invoices.maximum(:sequence) || 0) + 1
  end

  private
    def logo_must_be_a_supported_image
      return unless logo.attached?

      errors.add(:logo, "must be a PNG, JPG or WebP image") unless logo.content_type.in?(LOGO_CONTENT_TYPES)
      errors.add(:logo, "must be smaller than 5 MB") if logo.byte_size > LOGO_MAX_SIZE
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
