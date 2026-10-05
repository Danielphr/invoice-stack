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

  test "assigns the company's next number when first saved as issued" do
    company = companies(:one)

    first = create_invoice(company, status: "sent")
    second = create_invoice(company, status: "paid")

    assert_equal [ [ 2, "INV-2" ], [ 3, "INV-3" ] ], [ [ first.sequence, first.number ], [ second.sequence, second.number ] ]
    assert_equal 4, company.reload.next_invoice_number
  end

  test "builds the number from the pattern and the issue date" do
    company = companies(:one)
    company.update!(invoice_number_pattern: "YP-{YEAR}-{NUMBER}", invoice_number_digits: 4)

    invoice = create_invoice(company, status: "sent", issue_date: Date.new(2025, 12, 31))

    assert_equal "YP-2025-0002", invoice.number
  end

  test "leaves a draft without a number until it is sent" do
    draft = invoices(:globex_draft)
    assert_nil draft.number

    draft.update!(status: "sent")

    assert_equal [ 2, "INV-2" ], [ draft.sequence, draft.number ]
    assert_equal 3, draft.company.reload.next_invoice_number
  end

  test "dates a draft today when it is sent, keeping its payment term" do
    draft = invoices(:globex_draft)
    draft.update!(due_date: Date.new(2026, 9, 30))
    draft.company.update!(invoice_number_pattern: "INV-{YEAR}{MONTH}-{NUMBER}")

    travel_to Date.new(2026, 10, 3) do
      draft.update!(status: "sent")
    end

    assert_equal Date.new(2026, 10, 3), draft.issue_date
    assert_equal Date.new(2026, 10, 18), draft.due_date
    assert_equal "INV-202610-2", draft.number
  end

  test "keeps an issue date that is changed while sending" do
    draft = invoices(:globex_draft)

    travel_to Date.new(2026, 10, 3) do
      draft.update!(status: "sent", issue_date: Date.new(2026, 9, 20))
    end

    assert_equal Date.new(2026, 9, 20), draft.issue_date
  end

  test "keeps both dates when the due date is changed while sending" do
    draft = invoices(:globex_draft)

    travel_to Date.new(2026, 10, 3) do
      draft.update!(status: "sent", due_date: Date.new(2026, 10, 15))
    end

    assert_equal [ Date.new(2026, 9, 15), Date.new(2026, 10, 15) ], [ draft.issue_date, draft.due_date ]
  end

  test "keeps a later issue date and no due date when sent" do
    draft = invoices(:globex_draft)
    draft.update!(issue_date: Date.new(2026, 10, 10))

    travel_to Date.new(2026, 10, 3) do
      draft.update!(status: "sent")
    end

    assert_equal Date.new(2026, 10, 10), draft.issue_date
    assert_nil draft.due_date
  end

  test "keeps its number when cancelled and reopened" do
    @invoice.update!(status: "cancelled")
    @invoice.update!(status: "sent")

    assert_equal [ 1, "INV-001" ], [ @invoice.sequence, @invoice.number ]
    assert_equal 2, @invoice.company.reload.next_invoice_number
  end

  test "can't go back to draft once issued" do
    @invoice.status = "draft"

    assert_not @invoice.valid?
    assert_includes @invoice.errors[:status], "can't go back to draft once the invoice is issued"
  end

  test "can delete a draft but not an issued invoice" do
    assert_not @invoice.destroy
    assert_includes @invoice.errors[:base], "Only drafts can be deleted. Cancel the invoice instead."
    assert Invoice.exists?(@invoice.id)

    assert invoices(:globex_draft).destroy
  end

  test "database rejects a draft with a number" do
    assert_raises ActiveRecord::CheckViolation do
      invoices(:globex_draft).update_columns(number: "INV-9", sequence: 9)
    end
  end

  test "database rejects an issued invoice without a number" do
    assert_raises ActiveRecord::CheckViolation do
      @invoice.update_columns(number: nil, sequence: nil)
    end
  end

  test "ignores a number set before saving" do
    invoice = create_invoice(companies(:one), status: "sent", number: "SPECIAL-7")

    assert_equal "INV-2", invoice.number
  end

  test "database rejects a sequence used twice in the same company" do
    assert_raises ActiveRecord::RecordNotUnique do
      create_invoice(companies(:one), status: "sent").update_column(:sequence, 1)
    end
  end

  test "previews the next number without reserving it" do
    company = companies(:one)

    assert_equal "INV-2", company.preview_invoice_number(Date.current)
    assert_equal "INV-2", company.preview_invoice_number(Date.current)
    assert_equal 2, company.reload.next_invoice_number
  end

  test "rejects unknown statuses and billing types" do
    @invoice.status = "overdue"
    @invoice.billing_type = "daily"

    assert_not @invoice.valid?
    assert_includes @invoice.errors[:status], "is not included in the list"
    assert_includes @invoice.errors[:billing_type], "is not included in the list"
  end

  test "database rejects a number used twice in the same company" do
    assert_raises ActiveRecord::RecordNotUnique do
      create_invoice(companies(:one), status: "sent").update_column(:number, "INV-001")
    end
  end

  test "allows the same number in different companies" do
    assert_equal @invoice.number, invoices(:other_company_invoice).number
  end

  test "requires the client to belong to the same company" do
    @invoice.client = clients(:other_company_client)

    assert_not @invoice.valid?
    assert_includes @invoice.errors[:client], "is invalid"
  end

  test "can't be created for an archived client" do
    client = clients(:initech)
    client.archive
    invoice = companies(:one).invoices.new(client:, currency: "USD", issue_date: Date.current)
    invoice.items.build(description: "Design", quantity: 1, unit_price: 100)

    assert_not invoice.valid?
    assert_includes invoice.errors[:client], "is archived"
  end

  test "stays valid after its client is archived" do
    @invoice.client.archive

    assert @invoice.reload.valid?
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
    invoice = companies(:one).invoices.new(client: clients(:globex), currency: "USD", issue_date: Date.current)
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
    assert_difference "InvoiceItem.count", -1 do
      invoices(:globex_draft).destroy!
    end
  end

  test "sorts by number, not by when the invoice was created, so INV-9 comes before INV-10" do
    company = companies(:one)
    company.update!(next_invoice_number: 9)
    created_first = create_invoice(company)
    created_second = create_invoice(company, status: "sent")
    created_first.update!(status: "sent")
    scope = company.invoices.where(id: [ created_first, created_second ])

    assert_equal [ "INV-9", "INV-10" ], scope.sorted_by("number", "asc").map(&:number)
    assert_equal [ "INV-10", "INV-9" ], scope.sorted_by("number", "desc").map(&:number)
  end

  test "sorts drafts after the highest number" do
    company = companies(:one)
    scope = company.invoices.where(id: [ @invoice, invoices(:globex_draft) ])

    assert_equal [ "INV-001", nil ], scope.sorted_by("number", "asc").map(&:number)
    assert_equal [ nil, "INV-001" ], scope.sorted_by("number", "desc").map(&:number)
  end

  test "sorts by client name ignoring case" do
    company = companies(:one)
    clients(:initech).update!(name: "acme labs")
    acme = create_invoice(company, client: clients(:initech))
    globex = create_invoice(company, client: clients(:globex))

    assert_equal [ acme, globex ], company.invoices.where(id: [ acme, globex ]).sorted_by("client", "asc")
  end

  test "sorts by status in lifecycle order, with overdue between sent and paid" do
    company = companies(:one)
    overdue = create_invoice(company, status: "sent", issue_date: 2.months.ago, due_date: 1.month.ago)
    invoices = [ overdue, *%w[ paid draft cancelled sent ].map { create_invoice(company, status: it) } ]
    scope = company.invoices.where(id: invoices)

    statuses = ->(sorted) { sorted.map { it.overdue? ? "overdue" : it.status } }
    assert_equal %w[ draft sent overdue paid cancelled ], statuses.(scope.sorted_by("status", "asc"))
    assert_equal %w[ cancelled paid overdue sent draft ], statuses.(scope.sorted_by("status", "desc"))
  end

  test "treats an invoice due today as not yet overdue when sorting by status" do
    company = companies(:one)
    overdue = create_invoice(company, status: "sent", issue_date: 1.week.ago, due_date: Date.yesterday)
    due_today = create_invoice(company, status: "sent", due_date: Date.current)

    assert_not due_today.overdue?
    assert_equal [ due_today, overdue ], company.invoices.where(id: [ due_today, overdue ]).sorted_by("status", "asc")
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
