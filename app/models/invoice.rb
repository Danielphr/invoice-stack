class Invoice < ApplicationRecord
  belongs_to :company
  belongs_to :client
  has_many :items, -> { order(:position) }, class_name: "InvoiceItem", dependent: :destroy, inverse_of: :invoice
  has_many :events, -> { order(:created_at, :id) }, class_name: "InvoiceEvent", dependent: :delete_all

  accepts_nested_attributes_for :items, allow_destroy: true

  enum :status, %w[ draft sent paid cancelled ].index_by(&:itself), default: "draft", validate: true
  enum :billing_type, %w[ fixed hourly ].index_by(&:itself), default: "fixed", validate: true

  normalizes :notes, with: ->(notes) { notes.strip.presence }

  before_validation :position_items
  before_validation :sync_paid_on
  before_save :issue, if: -> { sequence.nil? && !draft? }
  before_save :collect_edited_fields
  after_create :record_creation
  after_update :record_changes
  # Issued invoices are cancelled instead, so their numbers are never lost or reused.
  before_destroy :ensure_draft, prepend: true, unless: :destroyed_by_association

  validates :issue_date, presence: true
  validates :currency, inclusion: { in: Currency.codes }
  validates :discount, numericality: { greater_than_or_equal_to: 0, less_than: 10_000_000_000 }
  validates :notes, length: { maximum: 500 }
  validate :client_must_belong_to_company
  validate :client_cannot_be_archived, if: :client_id_changed?
  validate :cannot_return_to_draft
  validate :cannot_switch_between_paid_and_cancelled
  validate :due_date_cannot_be_before_issue_date
  validate :must_have_items
  validate :must_be_closed_while_archived
  validate :discount_cannot_exceed_subtotal

  SORTS = %w[ number client issued due billing status total ].freeze

  DUE_SOON_DAYS = 14

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }
  scope :overdue, -> { where(overdue_condition) }
  scope :due_soon, -> { sent.where(due_date: Date.current..(Date.current + DUE_SOON_DAYS)) }

  # Mirrors #total: each item's amount is rounded before summing, as in InvoiceItem#amount.
  TOTAL_SQL = Arel.sql(<<~SQL.squish)
    (SELECT COALESCE(SUM(ROUND(invoice_items.quantity * invoice_items.unit_price, 2)), 0)
     FROM invoice_items WHERE invoice_items.invoice_id = invoices.id) - invoices.discount
  SQL
  private_constant :TOTAL_SQL

  # Same rule as #overdue?; if one changes, change the other.
  def self.overdue_condition
    arel_table[:status].eq("sent").and(arel_table[:due_date].lt(Date.current))
  end

  # Sums invoice totals in the database; combine with group to get one total per month or client.
  def self.sum_of_totals
    sum(TOTAL_SQL)
  end

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
      .when(overdue_condition).then(3)
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

  def archived?
    archived_at.present?
  end

  def archivable?
    paid? || cancelled?
  end

  def archive
    update(archived_at: Time.current)
  end

  def unarchive
    update(archived_at: nil)
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

    # Drafts are still being written, so only changes to issued invoices count as edits.
    # Status, payment date and archiving get their own entries.
    def collect_edited_fields
      @edited_fields = []
      return if sequence_was.nil?

      @edited_fields = changed - %w[ status paid_on archived_at updated_at ]
      @edited_fields << "paid_on" if paid_on_changed? && !status_changed?
      @edited_fields << "items" if items.any? { it.new_record? || it.marked_for_destruction? || it.changed? }
    end

    def record_creation
      record_event "created", to_status: status
    end

    def record_changes
      record_event "status_changed", from_status: status_before_last_save, to_status: status if saved_change_to_status?
      record_event "edited", fields: @edited_fields if @edited_fields.any?
      record_event(archived? ? "archived" : "unarchived") if saved_change_to_archived_at?
    end

    def record_event(action, **attributes)
      events.create!(action:, user: Current.user, **attributes)
    end

    def ensure_draft
      return if draft?

      errors.add(:base, "Only drafts can be deleted. Cancel the invoice instead.")
      throw :abort
    end

    # Only checked when the client is set or changed, so existing invoices stay valid after their client is archived.
    def client_cannot_be_archived
      errors.add(:client, "is archived") if client&.archived?
    end

    def cannot_return_to_draft
      errors.add(:status, "can't go back to draft once the invoice is issued") if draft? && sequence?
    end

    def client_must_belong_to_company
      errors.add(:client, :invalid) if client && client.company_id != company_id
    end

    # Reopen always goes back to "sent", so paid and cancelled must both be reached from sent.
    def cannot_switch_between_paid_and_cancelled
      return unless status_changed? && [ status_was, status ].sort == %w[ cancelled paid ]

      errors.add(:status, "can't change from #{status_was} to #{status}; reopen the invoice first")
    end

    def due_date_cannot_be_before_issue_date
      return unless issue_date && due_date

      errors.add(:due_date, "can't be before the issue date") if due_date < issue_date
    end

    def must_be_closed_while_archived
      return if !archived? || archivable?

      if status_changed?
        errors.add(:status, "can't change while the invoice is archived")
      else
        errors.add(:base, "Only paid or cancelled invoices can be archived")
      end
    end

    def must_have_items
      errors.add(:base, "Add at least one item") if active_items.empty?
    end

    def discount_cannot_exceed_subtotal
      return unless discount && active_items.all? { it.quantity && it.unit_price }

      errors.add(:discount, "can't be greater than the subtotal") if discount > subtotal
    end
end
