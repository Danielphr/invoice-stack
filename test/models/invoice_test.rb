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

  test "requires a number, issue date and supported currency" do
    invoice = Invoice.new(company: companies(:one), client: clients(:globex), number: " ", currency: "XYZ")

    assert_not invoice.valid?
    assert_includes invoice.errors[:number], "can't be blank"
    assert_includes invoice.errors[:issue_date], "can't be blank"
    assert_includes invoice.errors[:currency], "is not included in the list"
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
end
