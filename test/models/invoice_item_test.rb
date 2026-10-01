require "test_helper"

class InvoiceItemTest < ActiveSupport::TestCase
  setup do
    @item = invoice_items(:globex_development)
  end

  test "requires a description" do
    @item.description = "  "

    assert_not @item.valid?
    assert_includes @item.errors[:description], "can't be blank"
  end

  test "requires a positive quantity" do
    @item.quantity = 0

    assert_not @item.valid?
    assert_includes @item.errors[:quantity], "must be greater than 0"
  end

  test "does not allow a negative unit price" do
    @item.unit_price = -1

    assert_not @item.valid?
    assert_includes @item.errors[:unit_price], "must be greater than or equal to 0"
  end

  test "rejects values too large for the database columns" do
    @item.quantity = 100_000_000
    @item.unit_price = 10_000_000_000

    assert_not @item.valid?
    assert @item.errors[:quantity].any?
    assert @item.errors[:unit_price].any?
  end

  test "calculates its amount rounded to cents" do
    assert_equal BigDecimal("1000.00"), @item.amount

    @item.quantity = "0.33"
    @item.unit_price = "0.10"
    assert_equal BigDecimal("0.03"), @item.amount
  end
end
