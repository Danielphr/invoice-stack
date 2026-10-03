module InvoicesHelper
  STATUS_BADGE_CLASSES = {
    "draft" => "bg-gray-100 text-gray-700",
    "sent" => "bg-blue-50 text-blue-700",
    "paid" => "bg-green-50 text-green-700",
    "cancelled" => "bg-gray-100 text-gray-500 line-through",
    "overdue" => "bg-red-50 text-red-700"
  }.freeze

  # Several currencies share a symbol, so the code is always shown too:
  # "$1,200.00 USD", "R$950.00 BRL", "CHF 80.00".
  def format_money(amount, currency)
    details = Currency.find(currency)

    if details[:symbol] == currency
      number_to_currency(amount, unit: currency, precision: details[:precision], format: "%u %n")
    else
      "#{number_to_currency(amount, unit: details[:symbol], precision: details[:precision])} #{currency}"
    end
  end

  def invoice_title(invoice)
    invoice.number ? "Invoice #{invoice.number}" : "Draft invoice"
  end

  def invoice_number_preview(invoice)
    invoice.company.preview_invoice_number(invoice.issue_date_when_sent)
  end

  def invoice_status_options(invoice)
    statuses = Invoice.statuses.keys
    statuses -= [ "draft" ] if invoice.sequence_in_database
    statuses.map { [ it.humanize, it ] }
  end

  def invoice_status_badge(invoice)
    status = invoice.overdue? ? "overdue" : invoice.status

    tag.span status.humanize, class: [ "inline-flex rounded-md px-2 py-1 text-xs font-medium", STATUS_BADGE_CLASSES.fetch(status) ]
  end

  def invoice_sort_header(label, column, align: :left)
    active = column == sort_column
    ascending = active && sort_direction == "asc"

    aria_sort = (ascending ? "ascending" : "descending" if active)

    tag.th scope: "col", class: [ "px-4 py-3", ("text-right" if align == :right) ], aria: { sort: aria_sort } do
      link_to invoices_path(sort: column, direction: ascending ? "desc" : "asc"),
          class: "inline-flex items-center gap-1 hover:text-indigo-600" do
        safe_join([ label, (tag.span(ascending ? "▲" : "▼", aria: { hidden: true }) if active) ].compact)
      end
    end
  end

  ITEM_LABELS = {
    "fixed" => { quantity: "Quantity", unit_price: "Price" },
    "hourly" => { quantity: "Hours", unit_price: "Rate" }
  }.freeze

  def quantity_label(invoice)
    ITEM_LABELS.fetch(invoice.billing_type)[:quantity]
  end

  def unit_price_label(invoice)
    ITEM_LABELS.fetch(invoice.billing_type)[:unit_price]
  end

  def issued_invoice_warning(invoice)
    status = issued_status(invoice)
    return unless status

    "This invoice has been #{status}. Your client may already have it, so any change alters a document you already issued."
  end

  private
    def issued_status(invoice)
      status = invoice.status_in_database
      status if invoice.persisted? && status != "draft"
    end
end
