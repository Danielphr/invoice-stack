class InvoicePdf
  include ActionView::Helpers::NumberHelper
  include InvoicesHelper

  FONT_DIRECTORY = Rails.root.join("vendor/fonts/lato")
  MUTED = "6B7280"
  RULE = "E5E7EB"

  attr_reader :invoice

  def initialize(invoice)
    @invoice = invoice
  end

  def render
    @pdf = Prawn::Document.new(page_size: "A4", margin: 48, info: { Title: "Invoice #{invoice.number}" })
    use_lato

    header
    details
    items
    totals
    notes
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
    end

    def header
      company = invoice.company
      top = pdf.cursor
      half = pdf.bounds.width / 2

      pdf.bounding_box([ 0, top ], width: half) do
        pdf.text company.name, size: 18, style: :bold
        pdf.move_down 4
        company.address_lines.each { pdf.text it, color: MUTED }
        pdf.text company.email, color: MUTED if company.email
      end
      company_bottom = pdf.cursor

      pdf.bounding_box([ half, top ], width: half) do
        pdf.text "INVOICE", size: 18, style: :bold, align: :right
        pdf.text invoice.number, color: MUTED, align: :right
      end

      pdf.move_cursor_to [ company_bottom, pdf.cursor ].min
      pdf.move_down 32
    end

    def details
      top = pdf.cursor
      half = pdf.bounds.width / 2

      pdf.bounding_box([ 0, top ], width: half) do
        label "Bill to"
        pdf.text invoice.client.name, style: :bold
        invoice.client.address_lines.each { pdf.text it }
        contact = [ invoice.client.contact_name, invoice.client.contact_email || invoice.client.email ].compact
        pdf.text contact.join(" · ") if contact.any?
      end
      bill_to_bottom = pdf.cursor

      pdf.bounding_box([ half, top ], width: half) do
        detail "Issue date", format_date(invoice.issue_date)
        detail "Due date", format_date(invoice.due_date) if invoice.due_date
        detail "Paid on", format_date(invoice.paid_on) if invoice.paid?
        detail "Currency", invoice.currency
      end

      pdf.move_cursor_to [ bill_to_bottom, pdf.cursor ].min
      pdf.move_down 32
    end

    def items
      item_header

      invoice.items.each do |item|
        item_row({
          description: item.description,
          quantity: number_with_precision(item.quantity, precision: 2, strip_insignificant_zeros: true),
          unit_price: format_money(item.unit_price, invoice.currency),
          amount: format_money(item.amount, invoice.currency)
        })
      end
    end

    def item_header
      item_row({ description: "Description", quantity: quantity_label(invoice), unit_price: unit_price_label(invoice), amount: "Amount" },
        header: true)
    end

    def item_columns
      @item_columns ||= begin
        numbers = { quantity: 60, unit_price: 110, amount: 110 }
        { description: pdf.bounds.width - numbers.values.sum, **numbers }
      end
    end

    def item_row(values, header: false)
      style = header ? :bold : :normal
      height = pdf.height_of(values[:description], width: item_columns[:description] - 8, style: style) + 12

      if pdf.cursor < height
        pdf.start_new_page
        item_header unless header
      end

      top = pdf.cursor
      x = 0
      item_columns.each do |column, width|
        pdf.text_box values[column], at: [ x, top - 6 ], width: column == :description ? width - 8 : width,
          style: style, align: column == :description ? :left : :right
        x += width
      end

      pdf.move_down height
      pdf.stroke_color RULE
      pdf.stroke_horizontal_rule
    end

    def totals
      pdf.move_down 16
      pdf.start_new_page if pdf.cursor < 70

      width = 220
      pdf.bounding_box([ pdf.bounds.width - width, pdf.cursor ], width: width) do
        total_line "Subtotal", invoice.subtotal
        total_line "Discount", -invoice.discount if invoice.discount.positive?
        pdf.move_down 4
        total_line "Total", invoice.total, style: :bold
      end
    end

    def notes
      return unless invoice.notes

      pdf.move_down 32
      label "Notes"
      pdf.text invoice.notes
    end

    def page_numbers
      pdf.number_pages "Page <page> of <total>", at: [ 0, -16 ], width: pdf.bounds.width, align: :right, size: 8, color: MUTED
    end

    def label(text)
      pdf.text text.upcase, size: 8, style: :bold, color: MUTED
      pdf.move_down 4
    end

    def detail(name, value)
      pdf.text "#{name}: #{value}", align: :right
    end

    def total_line(name, amount, style: :normal)
      pdf.float { pdf.text name, style: style }
      pdf.text format_money(amount, invoice.currency), align: :right, style: style
    end

    def format_date(date)
      I18n.l(date, format: :medium)
    end
end
