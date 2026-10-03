class Invoice < ApplicationRecord
  belongs_to :company
  belongs_to :client
  has_many :items, -> { order(:position) }, class_name: "InvoiceItem", dependent: :destroy, inverse_of: :invoice

  accepts_nested_attributes_for :items, allow_destroy: true

  enum :status, %w[ draft sent paid cancelled ].index_by(&:itself), default: "draft", validate: true
  enum :billing_type, %w[ fixed hourly ].index_by(&:itself), default: "fixed", validate: true

  normalizes :notes, with: ->(notes) { notes.strip.presence }

  before_validation :position_items
  before_validation :sync_paid_on
  before_save :issue, if: -> { sequence.nil? && !draft? }
  # Issued invoices are cancelled instead, so their numbers are never lost or reused.
  before_destroy :ensure_draft, prepend: true, unless: :destroyed_by_association

  validates :issue_date, presence: true
  validates :currency, inclusion: { in: Currency.codes }
  validates :discount, numericality: { greater_than_or_equal_to: 0, less_than: 10_000_000_000 }
  validates :notes, length: { maximum: 500 }
  validate :client_must_belong_to_company
  validate :cannot_return_to_draft
  validate :due_date_cannot_be_before_issue_date
  validate :must_have_items
  validate :discount_cannot_exceed_subtotal

  SORTS = %w[ number client issued due billing status total ].freeze

  # Mirrors #total: each item's amount is rounded before summing, as in InvoiceItem#amount.
  TOTAL_SQL = Arel.sql(<<~SQL.squish)
    (SELECT COALESCE(SUM(ROUND(invoice_items.quantity * invoice_items.unit_price, 2)), 0)
     FROM invoice_items WHERE invoice_items.invoice_id = invoices.id) - invoices.discount
  SQL
  private_constant :TOTAL_SQL

  def self.sorted_by(column, direction)
    direction = direction.to_s == "asc" ? :asc : :desc

    relation =
      case column.to_s
      when "client" then joins(:client).order(Client.arel_table[:name].lower.public_send(direction))
      when "issued" then order(issue_date: direction)
      when "due" then order(arel_table[:due_date].public_send(direction).nulls_last)
      when "billing" then order(billing_type: direction)
      when "status" then order(status_rank.public_send(direction))
      # Amounts in different currencies can't be compared, so each currency is grouped.
      when "total" then order(:currency, TOTAL_SQL.public_send(direction))
      # Drafts get the next number when sent, so they sort after the highest one.
      else
        sequence = arel_table[:sequence].public_send(direction)
        order(direction == :asc ? sequence.nulls_last : sequence.nulls_first)
      end

    relation.order(id: direction)
  end

  def self.status_rank
    status = arel_table[:status]

    Arel::Nodes::Case.new
      # Same rule as #overdue?; if one changes, change the other.
      .when(status.eq("sent").and(arel_table[:due_date].lt(Date.current))).then(3)
      .when(status.eq("draft")).then(1)
      .when(status.eq("sent")).then(2)
      .when(status.eq("paid")).then(4)
      .else(5)
  end
  private_class_method :status_rank

  def subtotal
    active_items.sum(&:amount)
  end

  def total
    subtotal - discount.to_d
  end

  # Drafts are issued with today's date, unless they are already dated later.
  def issue_date_when_sent
    [ issue_date || Date.current, Date.current ].max
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

    def sync_paid_on
      if paid?
        self.paid_on ||= Date.current
      else
        self.paid_on = nil
      end
    end

    def issue
      reschedule(issue_date_when_sent) unless issue_date_changed? || due_date_changed?
      self.sequence = company.reserve_invoice_sequence
      self.number = company.format_invoice_number(sequence, issue_date)
    end

    # Keeps the payment term: due 3 days after issue stays due 3 days after the new date.
    def reschedule(date)
      term = due_date - issue_date if due_date
      self.issue_date = date
      self.due_date = date + term if term
    end

    def ensure_draft
      return if draft?

      errors.add(:base, "Only drafts can be deleted. Cancel the invoice instead.")
      throw :abort
    end

    def cannot_return_to_draft
      errors.add(:status, "can't go back to draft once the invoice is issued") if draft? && sequence?
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
