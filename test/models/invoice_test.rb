require "test_helper"

class InvoiceTest < ActiveSupport::TestCase
  setup do
    @invoice = invoices(:globex_website)
  end

  test "fixtures are valid" do
    assert invoices(:globex_website).valid?
    assert invoices(:other_company_invoice).valid?
  end

  test "defaults to a draft, fixed-price invoice" do
    invoice = Invoice.new

    assert invoice.draft?
    assert invoice.fixed?
  end

  test "requires an issue date and supported currency" do
    invoice = Invoice.new(company: companies(:one), client: clients(:globex), currency: "XYZ")

    assert_not invoice.valid?
    assert_includes invoice.errors[:issue_date], "can't be blank"
    assert_includes invoice.errors[:currency], "is not included in the list"
  end

  test "requires a number once the invoice exists" do
    @invoice.number = " "

    assert_not @invoice.valid?
    assert_includes @invoice.errors[:number], "can't be blank"
  end

  test "assigns the company's next number when saved without one" do
    company = companies(:one)

    first = create_invoice(company)
    second = create_invoice(company)

    assert_equal [ "INV-1", "INV-2" ], [ first.number, second.number ]
    assert_equal 3, company.reload.next_invoice_number
  end

  test "builds the number from the pattern and the issue date" do
    company = companies(:one)
    company.update!(invoice_number_pattern: "YP-{YEAR}-{NUMBER}", invoice_number_digits: 4)

    invoice = create_invoice(company, issue_date: Date.new(2025, 12, 31))

    assert_equal "YP-2025-0001", invoice.number
  end

  test "keeps a manually entered number without advancing the counter" do
    company = companies(:one)

    invoice = create_invoice(company, number: "SPECIAL-7")

    assert_equal "SPECIAL-7", invoice.number
    assert_equal 1, company.reload.next_invoice_number
  end

  test "skips numbers that were already used manually" do
    company = companies(:one)
    create_invoice(company, number: "INV-1")
    create_invoice(company, number: "INV-2")

    invoice = create_invoice(company)

    assert_equal "INV-3", invoice.number
    assert_equal 4, company.reload.next_invoice_number
  end

  test "previews the next number without reserving it" do
    company = companies(:one)

    assert_equal "INV-1", company.preview_invoice_number(Date.current)
    assert_equal "INV-1", company.preview_invoice_number(Date.current)
    assert_equal 1, company.reload.next_invoice_number
  end

  test "rejects unknown statuses and billing types" do
    @invoice.status = "overdue"
    @invoice.billing_type = "daily"

    assert_not @invoice.valid?
    assert_includes @invoice.errors[:status], "is not included in the list"
    assert_includes @invoice.errors[:billing_type], "is not included in the list"
  end

  test "requires a number that is unique within the company" do
    duplicate = companies(:one).invoices.new(@invoice.attributes.slice("client_id", "currency", "issue_date", "number"))
    duplicate.items.build(description: "Work", quantity: 1, unit_price: 10)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:number], "has already been taken"
  end

  test "allows the same number in different companies" do
    assert_equal @invoice.number, invoices(:other_company_invoice).number
  end

  test "requires the client to belong to the same company" do
    @invoice.client = clients(:other_company_client)

    assert_not @invoice.valid?
    assert_includes @invoice.errors[:client], "is invalid"
  end

  test "database rejects a client from another company" do
    assert_raises ActiveRecord::InvalidForeignKey do
      @invoice.update_column(:client_id, clients(:other_company_client).id)
    end
  end

  test "database rejects an unknown status" do
    assert_raises ActiveRecord::StatementInvalid do
      @invoice.update_column(:status, "overdue")
    end
  end

  test "requires at least one item" do
    @invoice.items.each(&:mark_for_destruction)

    assert_not @invoice.valid?
    assert_includes @invoice.errors[:base], "Add at least one item"
  end

  test "does not allow a due date before the issue date" do
    @invoice.due_date = @invoice.issue_date - 1

    assert_not @invoice.valid?
    assert_includes @invoice.errors[:due_date], "can't be before the issue date"
  end

  test "calculates subtotal and total from its items" do
    assert_equal BigDecimal("2200.00"), @invoice.subtotal
    assert_equal BigDecimal("2150.00"), @invoice.total
  end

  test "rounds each line to cents before adding them up" do
    invoice = Invoice.new
    invoice.items.build(quantity: "0.33", unit_price: "0.10")
    invoice.items.build(quantity: "0.33", unit_price: "0.10")

    assert_equal BigDecimal("0.06"), invoice.subtotal
  end

  test "does not allow a discount greater than the subtotal" do
    @invoice.discount = 2200.01

    assert_not @invoice.valid?
    assert_includes @invoice.errors[:discount], "can't be greater than the subtotal"
  end

  test "numbers items in order" do
    invoice = companies(:one).invoices.new(client: clients(:globex), number: "INV-002", currency: "USD", issue_date: Date.current)
    invoice.items.build(description: "First", quantity: 1, unit_price: 10)
    invoice.items.build(description: "Second", quantity: 1, unit_price: 20)

    invoice.save!

    assert_equal [ "First", "Second" ], invoice.items.reload.map(&:description)
    assert_equal [ 0, 1 ], invoice.items.map(&:position)
  end

  test "records today as the payment date when marked as paid" do
    @invoice.update!(status: "paid")

    assert_equal Date.current, @invoice.paid_on
  end

  test "keeps a payment date that was entered" do
    @invoice.update!(status: "paid", paid_on: Date.new(2026, 9, 15))

    assert_equal Date.new(2026, 9, 15), @invoice.reload.paid_on
  end

  test "clears the payment date when no longer paid" do
    @invoice.update!(status: "paid")
    @invoice.update!(status: "sent")

    assert_nil @invoice.reload.paid_on
  end

  test "database requires a payment date exactly when paid" do
    assert_raises ActiveRecord::StatementInvalid do
      @invoice.update_column(:status, "paid")
    end
  end

  test "is overdue when sent and past its due date" do
    @invoice.due_date = Date.current - 1
    assert @invoice.overdue?

    @invoice.status = "paid"
    assert_not @invoice.overdue?
  end

  test "destroys its items when destroyed" do
    assert_difference "InvoiceItem.count", -2 do
      @invoice.destroy!
    end
  end

  test "sorts by number in creation order, so INV-9 comes before INV-10" do
    company = companies(:one)
    company.update!(next_invoice_number: 9)
    nine = create_invoice(company)
    ten = create_invoice(company)

    assert_equal [ "INV-9", "INV-10" ], company.invoices.where(id: [ nine, ten ]).sorted_by("number", "asc").map(&:number)
    assert_equal [ "INV-10", "INV-9" ], company.invoices.where(id: [ nine, ten ]).sorted_by("number", "desc").map(&:number)
  end

  test "sorts by client name ignoring case" do
    company = companies(:one)
    clients(:initech).update!(name: "acme labs")
    acme = create_invoice(company, client: clients(:initech))
    globex = create_invoice(company, client: clients(:globex))

    assert_equal [ acme, globex ], company.invoices.where(id: [ acme, globex ]).sorted_by("client", "asc")
  end

  test "sorts by status in lifecycle order" do
    company = companies(:one)
    invoices = %w[ paid draft cancelled sent ].map { create_invoice(company, status: it) }

    scope = company.invoices.where(id: invoices)

    assert_equal %w[ draft sent paid cancelled ], scope.sorted_by("status", "asc").map(&:status)
    assert_equal %w[ cancelled paid sent draft ], scope.sorted_by("status", "desc").map(&:status)
  end

  test "puts invoices without a due date last in either direction" do
    company = companies(:one)
    undated = create_invoice(company, due_date: nil)
    early = create_invoice(company, due_date: 1.week.from_now)
    late = create_invoice(company, due_date: 2.weeks.from_now)
    scope = company.invoices.where(id: [ undated, early, late ])

    assert_equal [ early, late, undated ], scope.sorted_by("due", "asc")
    assert_equal [ late, early, undated ], scope.sorted_by("due", "desc")
  end

  test "sorts by total after the discount, grouping each currency" do
    company = companies(:one)
    hundred = create_invoice(company, items: [ [ 1, 100 ] ])
    ninety = create_invoice(company, items: [ [ 2, 80 ] ], discount: 70)
    euros = create_invoice(company, items: [ [ 1, 1000 ] ], currency: "EUR")
    scope = company.invoices.where(id: [ hundred, ninety, euros ])

    assert_equal [ euros, ninety, hundred ], scope.sorted_by("total", "asc")
    assert_equal [ euros, hundred, ninety ], scope.sorted_by("total", "desc")
  end

  test "rounds each item before summing when sorting by total, like #total" do
    company = companies(:one)
    three_cents = create_invoice(company, items: [ [ 0.5, 0.01 ] ] * 3)
    two_cents = create_invoice(company, items: [ [ 1, 0.02 ] ])

    assert_equal 0.03.to_d, three_cents.total
    assert_equal [ two_cents, three_cents ], company.invoices.where(id: [ three_cents, two_cents ]).sorted_by("total", "asc")
  end

  private
    def create_invoice(company, items: [ [ 1, 100 ] ], **attributes)
      invoice = company.invoices.new(client: clients(:globex), currency: "USD", issue_date: Date.current, **attributes)
      items.each { |quantity, unit_price| invoice.items.build(description: "Work", quantity:, unit_price:) }
      invoice.save!
      invoice
    end
end
