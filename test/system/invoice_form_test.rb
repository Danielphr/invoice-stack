require "application_system_test_case"

class InvoiceFormTest < ApplicationSystemTestCase
  setup do
    sign_in_as users(:one)
  end

  test "previews totals as items are added, changed and removed" do
    visit new_invoice_path
    select "Globex Corporation", from: "Client"

    fill_item 0, "Design", quantity: 2, unit_price: 600
    within(item_row(0)) { assert_text "$1,200.00" }

    click_on "+ Add item"
    fill_item 1, "Hosting", quantity: 1, unit_price: 300
    assert_total "Subtotal", "$1,500.00"

    fill_in "Discount", with: "100"
    assert_total "Total", "$1,400.00"

    within(item_row(1)) { click_on "Remove item" }
    assert_total "Total", "$1,100.00"

    click_on "Create Invoice"
    assert_text "Invoice created."
    assert_text "$1,100.00 USD"
  end

  test "names the item columns after the billing type" do
    visit new_invoice_path

    select "Hourly", from: "Billing type"
    assert_selector "th", text: "Hours"
    assert_selector "th", text: "Rate"

    select "Fixed", from: "Billing type"
    assert_selector "th", text: "Quantity"
    assert_selector "th", text: "Price"
  end

  private
    # Item fields are labelled by their column headers, so they're found by name within each row.
    def fill_item(index, description, quantity:, unit_price:)
      within item_row(index) do
        find("input[name$='[description]']").set(description)
        find("input[name$='[quantity]']").set(quantity)
        find("input[name$='[unit_price]']").set(unit_price)
      end
    end

    def item_row(index)
      all("tr[data-invoice-form-target=item]:not([hidden])")[index]
    end

    def assert_total(label, amount)
      assert_selector "dl div", text: /#{label}\s*#{Regexp.escape(amount)}/
    end
end
