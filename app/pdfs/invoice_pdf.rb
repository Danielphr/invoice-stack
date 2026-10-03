class InvoicePdf
  include ActionView::Helpers::NumberHelper
  include InvoicesHelper

  FONT_DIRECTORY = Rails.root.join("vendor/fonts/lato")
  RULE = "E0E0E0"
  STRIPE = "F7F7F7"
  ITEM_ALIGNMENTS = { description: :left, quantity: :center, unit_price: :left, amount: :right }.freeze

  attr_reader :invoice

  def initialize(invoice)
    @invoice = invoice
  end

  def render
    @pdf = Prawn::Document.new(page_size: "A4", margin: 36, info: { Title: "Invoice #{invoice.number}" })
    use_lato

    header
    details
    items
    totals_and_notes
    page_numbers

    @pdf.render
  end

  def filename
    "#{invoice.number.gsub(/[^\w.-]+/, "-")}.pdf"
  end

  private
    attr_reader :pdf

    def use_lato
      pdf.font_families.update("Lato" => {
        normal: FONT_DIRECTORY.join("Lato-Regular.ttf").to_s,
        bold: FONT_DIRECTORY.join("Lato-Bold.ttf").to_s
      })
      pdf.font "Lato", size: 10
      pdf.default_leading 3
    end

    def header
      company = invoice.company
      top = pdf.cursor
      width = pdf.bounds.width
      bottoms = []

      pdf.bounding_box([ 0, top ], width: width * 0.35) { logo }
      bottoms << pdf.cursor

      pdf.bounding_box([ width * 0.38, top ], width: width * 0.3) do
        pdf.text company.name, color: accent
        pdf.text company.email if company.email
      end
      bottoms << pdf.cursor

      pdf.bounding_box([ width * 0.7, top ], width: width * 0.3) do
        company.address_lines.each { pdf.text it }
      end
      bottoms << pdf.cursor

      pdf.move_cursor_to bottoms.min
      pdf.move_down 28
      pdf.indent(8) { pdf.text "INVOICE", style: :bold, color: accent }
      pdf.move_down 8
      rule
      pdf.move_down 16
    end

    def details
      client = invoice.client
      top = pdf.cursor
      width = pdf.bounds.width

      pdf.bounding_box([ 8, top ], width: width * 0.38 - 8) do
        detail "Number", invoice.number
        detail "Invoice Date", format_date(invoice.issue_date)
        detail "Due Date", format_date(invoice.due_date) if invoice.due_date
        detail "Paid On", format_date(invoice.paid_on) if invoice.paid?
        detail "Invoice Total", format_money(invoice.total, invoice.currency)
      end
      details_bottom = pdf.cursor

      pdf.bounding_box([ width * 0.38, top ], width: width * 0.62) do
        pdf.text client.name, style: :bold
        [ client.contact_email || client.email, client.contact_phone || client.phone, *client.address_lines ]
          .compact.each { pdf.text it }
      end

      pdf.move_cursor_to [ details_bottom, pdf.cursor ].min
      pdf.move_down 16
      rule
    end

    def items
      item_header

      invoice.items.each_with_index do |item, index|
        item_row({
          description: item.description,
          quantity: number_with_precision(item.quantity, precision: 2, strip_insignificant_zeros: true),
          unit_price: format_money(item.unit_price, invoice.currency),
          amount: format_money(item.amount, invoice.currency)
        }, striped: index.even?)
      end
    end

    def item_header
      item_row({ description: "Description", quantity: quantity_label(invoice), unit_price: unit_price_label(invoice), amount: "Line Total" },
        header: true)
    end

    def item_columns
      @item_columns ||= begin
        numbers = { quantity: 70, unit_price: 110, amount: 110 }
        { description: pdf.bounds.width - numbers.values.sum, **numbers }
      end
    end

    def item_row(values, header: false, striped: false)
      style = header ? :bold : :normal
      height = pdf.height_of(values[:description], width: item_columns[:description] - 16, style: style) + 16

      if pdf.cursor < height
        pdf.start_new_page
        item_header unless header
      end

      top = pdf.cursor
      if striped
        pdf.fill_color STRIPE
        pdf.fill_rectangle [ 0, top ], pdf.bounds.width, height
        pdf.fill_color "000000"
      end

      x = 0
      item_columns.each do |column, width|
        pdf.text_box values[column], at: [ x + 8, top - 8 ], width: width - 16, style: style, align: ITEM_ALIGNMENTS.fetch(column)
        x += width
      end

      pdf.move_down height
      pdf.line_width(header ? 1.5 : 0.75)
      rule
      pdf.line_width 1
    end

    def totals_and_notes
      pdf.move_down 12
      pdf.start_new_page if pdf.cursor < 80

      top = pdf.cursor
      totals_width = item_columns[:unit_price] + item_columns[:amount]

      pdf.bounding_box([ pdf.bounds.width - totals_width, top ], width: totals_width) do
        total_line "Subtotal", invoice.subtotal
        total_line "Discount", invoice.discount
        total_line "Total", invoice.total, style: :bold
      end

      return unless invoice.notes

      pdf.bounding_box([ 8, top ], width: pdf.bounds.width - totals_width - 32) do
        pdf.text invoice.notes, size: 8
      end
    end

    def page_numbers
      return if pdf.page_count == 1

      pdf.number_pages "Page <page> of <total>", at: [ 0, -16 ], width: pdf.bounds.width, align: :right, size: 8, color: "6B7280"
    end

    def logo
      return unless invoice.company.logo.attached?

      pdf.image StringIO.new(invoice.company.logo.variant(:document).processed.download), fit: [ 150, 70 ]
    rescue ActiveStorage::FileNotFoundError, Vips::Error
      # A missing or unreadable logo file shouldn't stop the invoice from rendering.
    end

    def accent
      invoice.company.accent_color.delete_prefix("#")
    end

    def rule
      pdf.stroke_color RULE
      pdf.stroke_horizontal_rule
    end

    def detail(name, value)
      pdf.float { pdf.text name }
      pdf.indent(80) { pdf.text value }
    end

    def total_line(name, amount, style: :normal)
      pdf.float { pdf.indent(8) { pdf.text name, style: style } }
      pdf.indent(0, 8) { pdf.text format_money(amount, invoice.currency), align: :right, style: style }
      pdf.move_down 6
    end

    def format_date(date)
      I18n.l(date, format: :long)
    end
end
