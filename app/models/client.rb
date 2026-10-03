class Client < ApplicationRecord
  # Optional leading "+", then 7 to 15 digits (the E.164 maximum) that may be
  # separated by spaces, dots, dashes or parentheses.
  PHONE_FORMAT = /\A\+?(?:[\s().-]*\d){7,15}[\s().-]*\z/

  SORTS = %w[ name location invoices ].freeze
  Stats = Data.define(:invoices_count, :overdue_count, :outstanding)

  INVOICES_COUNT_SQL = Arel.sql("(SELECT COUNT(*) FROM invoices WHERE invoices.client_id = clients.id)")
  private_constant :INVOICES_COUNT_SQL

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

  def self.sorted_by(column, direction)
    direction = direction.to_s == "desc" ? :desc : :asc

    relation =
      case column.to_s
      when "location" then order(arel_table[:city].lower.public_send(direction))
      when "invoices" then order(INVOICES_COUNT_SQL.public_send(direction))
      else order(arel_table[:name].lower.public_send(direction))
      end

    relation.order(id: direction)
  end

  # Invoice counts and amounts owed for a list of clients, in three grouped queries rather than three per client.
  # Outstanding amounts are kept per currency: { "USD" => amount }.
  def self.invoice_stats(clients)
    invoices = Invoice.where(client: clients)
    counts = invoices.group(:client_id).count
    overdue = invoices.overdue.group(:client_id).count
    outstanding = invoices.sent.group(:client_id, :currency).order(:currency).sum_of_totals

    clients.to_h do |client|
      amounts = outstanding.filter_map { |(client_id, currency), amount| [ currency, amount ] if client_id == client.id }.to_h
      [ client.id, Stats.new(invoices_count: counts.fetch(client.id, 0), overdue_count: overdue.fetch(client.id, 0), outstanding: amounts) ]
    end
  end

  def initials
    name.scan(/\p{L}+/).first(2).map { it[0] }.join.upcase
  end

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
