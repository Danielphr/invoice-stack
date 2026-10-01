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

  def invoice_status_badge(invoice)
    status = invoice.overdue? ? "overdue" : invoice.status

    tag.span status.humanize, class: [ "inline-flex rounded-md px-2 py-1 text-xs font-medium", STATUS_BADGE_CLASSES.fetch(status) ]
  end

  def quantity_label(invoice)
    invoice.hourly? ? "Hours" : "Quantity"
  end

  def unit_price_label(invoice)
    invoice.hourly? ? "Rate" : "Price"
  end
end
