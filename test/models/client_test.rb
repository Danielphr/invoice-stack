require "test_helper"

class ClientTest < ActiveSupport::TestCase
  setup do
    @client = clients(:globex)
  end

  test "fixtures are valid" do
    assert clients(:globex).valid?
    assert clients(:initech).valid?
  end

  test "requires name, city and country" do
    client = Client.new(company: companies(:one))

    assert_not client.valid?
    assert_includes client.errors[:name], "can't be blank"
    assert_includes client.errors[:city], "can't be blank"
    assert_includes client.errors[:country], "can't be blank"
  end

  test "requires a supported country code" do
    @client.country = "United States"

    assert_not @client.valid?
    assert_includes @client.errors[:country], "is not included in the list"
  end

  test "belongs to a company" do
    @client.company = nil

    assert_not @client.valid?
  end

  test "stores blank optional fields as nil" do
    client = Client.new(email: "  ", phone: "", website: " ", notes: "  ", address_line2: "")

    assert_nil client.email
    assert_nil client.phone
    assert_nil client.website
    assert_nil client.notes
    assert_nil client.address_line2
  end

  test "strips whitespace and downcases email addresses" do
    client = Client.new(name: "  Acme  ", email: " Billing@ACME.example ", contact_email: " Ann@ACME.example ")

    assert_equal "Acme", client.name
    assert_equal "billing@acme.example", client.email
    assert_equal "ann@acme.example", client.contact_email
  end

  test "rejects invalid email addresses" do
    @client.email = "not-an-email"
    @client.contact_email = "also not"

    assert_not @client.valid?
    assert_includes @client.errors[:email], "is invalid"
    assert_includes @client.errors[:contact_email], "is invalid"
  end

  test "accepts phone numbers with or without a country code" do
    [ "+598 99 123 456", "+1 (555) 123-4567", "555.123.4567", "099123456" ].each do |number|
      @client.phone = number
      @client.contact_phone = number

      assert @client.valid?, "expected #{number.inspect} to be valid"
    end
  end

  test "rejects malformed phone numbers" do
    [ "abc", "+12", "12345678901234567", "++598 99 123 456", "555-1234 ext 2" ].each do |number|
      @client.phone = number

      assert_not @client.valid?, "expected #{number.inspect} to be invalid"
      assert_includes @client.errors[:phone], "is invalid"
    end
  end

  test "limits phone numbers to 30 characters" do
    @client.phone = "1" + " " * 30 + "234567"

    assert_not @client.valid?
    assert_includes @client.errors[:phone], "is too long (maximum is 30 characters)"
  end

  test "adds https to a website without a scheme" do
    assert_equal "https://acme.example", Client.new(website: "acme.example").website
    assert_equal "http://acme.example", Client.new(website: "http://acme.example").website
  end

  test "rejects websites that are not web addresses" do
    [ "localhost", "javascript:alert(1)", "ftp://acme.example", "https://exa mple.com" ].each do |url|
      @client.website = url

      assert_not @client.valid?, "expected #{url.inspect} to be invalid"
      assert_includes @client.errors[:website], "is invalid"
    end
  end

  test "limits notes to 500 characters" do
    @client.notes = "a" * 501

    assert_not @client.valid?
    assert_includes @client.errors[:notes], "is too long (maximum is 500 characters)"
  end

  test "returns the country name" do
    assert_equal "United States", @client.country_name
  end

  test "formats the address as lines, skipping blank parts" do
    assert_equal [ "742 Evergreen Terrace", "Springfield, Illinois, 62701", "United States" ], @client.address_lines
    assert_equal [ "Montevideo", "Uruguay" ], clients(:initech).address_lines
  end

  test "joins the contact name" do
    assert_equal "Hank Scorpio", @client.contact_name
    assert_nil clients(:initech).contact_name
  end

  test "cannot be destroyed while it has invoices" do
    assert_not @client.destroy
    assert @client.reload
    assert_includes @client.errors[:base], "Cannot delete record because dependent invoices exist"
  end

  test "sorts by name, location or invoice count" do
    company = companies(:one)
    acme = company.clients.create!(name: "acme labs", city: "Zurich", country: "CH")
    scope = company.clients.where(id: [ acme, clients(:globex), clients(:initech) ])

    assert_equal [ acme, clients(:globex), clients(:initech) ], scope.sorted_by("name", "asc").to_a
    assert_equal [ clients(:initech), clients(:globex), acme ], scope.sorted_by("location", "asc").to_a
    assert_equal clients(:globex), scope.sorted_by("invoices", "desc").first
  end

  test "summarizes invoices for a list of clients" do
    travel_to Date.new(2026, 10, 15)
    company = companies(:one)
    company.invoices.create!(client: clients(:globex), currency: "EUR", status: "sent", issue_date: Date.current, due_date: Date.current,
      items_attributes: [ { description: "Work", quantity: 1, unit_price: 100 } ])

    stats = Client.invoice_stats(company.clients.where(id: [ clients(:globex), clients(:initech) ]))

    assert_equal 3, stats[clients(:globex).id].invoices_count
    assert_equal 1, stats[clients(:globex).id].overdue_count
    assert_equal({ "EUR" => 100, "USD" => 2150 }, stats[clients(:globex).id].outstanding)
    assert_equal [ 0, 0, {} ], stats[clients(:initech).id].to_h.values
  end

  test "summarizes what the client was billed, paid and owes, per currency" do
    travel_to Date.new(2026, 10, 15)
    client = clients(:globex)
    client.company.invoices.create!(client:, currency: "EUR", status: "paid", issue_date: Date.current, paid_on: Date.current,
      items_attributes: [ { description: "Work", quantity: 1, unit_price: 300 } ])
    client.company.invoices.create!(client:, currency: "USD", status: "cancelled", issue_date: Date.current,
      items_attributes: [ { description: "Work", quantity: 1, unit_price: 999 } ])

    summary = client.invoice_summary

    assert_equal [ 2, { "EUR" => 300, "USD" => 2150 } ], [ summary.billed.count, summary.billed.amounts ]
    assert_equal [ 1, { "EUR" => 300 } ], [ summary.paid.count, summary.paid.amounts ]
    assert_equal [ 1, { "USD" => 2150 } ], [ summary.outstanding.count, summary.outstanding.amounts ]
    assert_equal [ 1, { "USD" => 2150 } ], [ summary.overdue.count, summary.overdue.amounts ]
  end

  test "shows the website's host without www" do
    assert_equal "globex.example", clients(:globex).website_host
    assert_equal "example.com", Client.new(website: "https://www.example.com/about").website_host
    assert_nil Client.new.website_host
  end

  test "builds initials from the first two words of the name, skipping symbols" do
    assert_equal "GC", clients(:globex).initials
    assert_equal "I", clients(:initech).initials
    assert_equal "HP", Client.new(name: "Harbor & Pine").initials
    assert_equal "ÉM", Client.new(name: "études Montaña").initials
  end
end
