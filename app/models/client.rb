class Client < ApplicationRecord
  # Optional leading "+", then 7 to 15 digits (the E.164 maximum) that may be
  # separated by spaces, dots, dashes or parentheses.
  PHONE_FORMAT = /\A\+?(?:[\s().-]*\d){7,15}[\s().-]*\z/

  include HasAddress

  belongs_to :company
  has_many :invoices, dependent: :restrict_with_error

  scope :by_name, -> { order(arel_table[:name].lower) }

  normalizes :name, :contact_first_name, :contact_last_name, :phone, :contact_phone, :notes,
    with: ->(value) { value.strip.presence }
  normalizes :email, :contact_email, with: ->(email) { email.strip.downcase.presence }
  normalizes :website, with: ->(url) {
    url = url.strip.presence
    url.nil? || url.match?(%r{\Ahttps?://}i) ? url : "https://#{url}"
  }

  validates :name, presence: true, length: { maximum: 100 }
  validates :city, :country, presence: true
  validates :contact_first_name, :contact_last_name, length: { maximum: 100 }
  validates :notes, length: { maximum: 500 }
  validates :email, :contact_email, format: { with: URI::MailTo::EMAIL_REGEXP }, length: { maximum: 254 }, allow_nil: true
  validates :phone, :contact_phone, format: { with: PHONE_FORMAT }, length: { maximum: 30 }, allow_nil: true
  validates :website, length: { maximum: 255 }
  validate :website_must_be_a_web_address

  def contact_name
    [ contact_first_name, contact_last_name ].compact.join(" ").presence
  end

  private
    def website_must_be_a_web_address
      return if website.nil?

      uri = URI.parse(website)
      errors.add(:website, :invalid) unless uri.is_a?(URI::HTTP) && uri.host.to_s.include?(".")
    rescue URI::InvalidURIError
      errors.add(:website, :invalid)
    end
end
