require "test_helper"

class CompanyTest < ActiveSupport::TestCase
  test "onboarding is incomplete without a name" do
    company = Company.new

    assert_not company.onboarding_complete?
  end

  test "onboarding is incomplete with a blank name" do
    company = Company.new(name: "   ")

    assert_not company.onboarding_complete?
  end

  test "onboarding is complete with a name" do
    company = Company.new(name: "Acme Inc.")

    assert company.onboarding_complete?
  end

  test "name is required on update" do
    company = companies(:one)
    company.name = ""

    assert_not company.valid?
    assert_includes company.errors[:name], "can't be blank"
  end

  test "destroying a company removes its invoices, clients and users" do
    company = companies(:one)

    company.destroy!

    assert_empty Invoice.where(company: company)
    assert_empty Client.where(company: company)
    assert_empty User.where(company: company)
  end

  test "defaults new companies to UTC and US dollars" do
    company = Company.new

    assert_equal "UTC", company.time_zone
    assert_equal "USD", company.default_currency
  end

  test "allows a company without email or address" do
    company = companies(:one)

    assert company.valid?
    assert_empty company.address_lines
  end

  test "normalizes and validates the email" do
    company = companies(:one)

    company.email = " Billing@ACME.example "
    assert_equal "billing@acme.example", company.email

    company.email = "not an email"
    assert_not company.valid?
    assert_includes company.errors[:email], "is invalid"
  end

  test "defaults the accent color to black and stores it lowercase" do
    company = Company.new
    assert_equal "#000000", company.accent_color

    company.accent_color = " #4F46E5 "
    assert_equal "#4f46e5", company.accent_color
  end

  test "requires a six-digit hex accent color" do
    company = companies(:one)

    [ "red", "#fff", "4f46e5", "#4f46e5ff" ].each do |color|
      company.accent_color = color

      assert_not company.valid?, "expected #{color.inspect} to be invalid"
      assert_includes company.errors[:accent_color], "must be a hex color like #4f46e5"
    end
  end

  test "database rejects an invalid accent color" do
    assert_raises ActiveRecord::StatementInvalid do
      companies(:one).update_column(:accent_color, "red")
    end
  end

  test "accepts a PNG logo and makes a document-sized PNG variant" do
    company = companies(:one)
    company.logo.attach(io: file_fixture("logo.png").open, filename: "logo.png")

    assert company.valid?

    variant = Vips::Image.new_from_buffer(company.logo.variant(:document).processed.download, "")
    assert_equal [ 600, 200 ], [ variant.width, variant.height ]
  end

  test "rejects a logo that is not a PNG, JPG or WebP image, whatever its name" do
    company = companies(:one)
    company.logo.attach(io: file_fixture("logo.svg").open, filename: "logo.png")

    assert_not company.valid?
    assert_includes company.errors[:logo], "must be a PNG, JPG or WebP image"
  end

  test "rejects a logo larger than 5 MB" do
    company = companies(:one)
    company.logo.attach(io: StringIO.new("0" * (5.megabytes + 1)), filename: "huge.png")

    assert_not company.valid?
    assert_includes company.errors[:logo], "must be smaller than 5 MB"
  end

  test "has a complete address with line 1, city and country" do
    company = Company.new(address_line1: "100 Example Street", city: "Springfield")
    assert_not company.address_complete?

    company.country = "US"
    assert company.address_complete?
  end

  test "formats its address like a client's" do
    company = Company.new(address_line1: "100 Example Street", city: "Springfield", state: "Illinois",
      postal_code: "62701", country: "US")

    assert_equal [ "100 Example Street", "Springfield, Illinois, 62701", "United States" ], company.address_lines
  end

  test "rejects an unsupported country, time zone or currency" do
    company = companies(:one)
    company.country = "XX"
    company.time_zone = "Mars/Olympus"
    company.default_currency = "XYZ"

    assert_not company.valid?
    assert_includes company.errors[:country], "is not included in the list"
    assert_includes company.errors[:time_zone], "is not included in the list"
    assert_includes company.errors[:default_currency], "is not included in the list"
  end

  test "starts invoice numbering at INV-1" do
    company = Company.new

    assert_equal "INV-{NUMBER}", company.invoice_number_pattern
    assert_equal "INV-1", company.format_invoice_number(company.next_invoice_number, Date.new(2026, 10, 2))
  end

  test "formats invoice numbers with padding and the issue date" do
    company = Company.new(invoice_number_pattern: "YP-{YEAR}{MONTH}-{NUMBER}", invoice_number_digits: 4)

    assert_equal "YP-202603-0042", company.format_invoice_number(42, Date.new(2026, 3, 15))
  end

  test "does not truncate numbers longer than the minimum digits" do
    company = Company.new(invoice_number_digits: 2)

    assert_equal "INV-12345", company.format_invoice_number(12345, Date.current)
  end

  test "accepts valid invoice number patterns" do
    company = companies(:one)

    [ "INV-{NUMBER}", "YP-{YEAR}-{NUMBER}", "{YEAR}{MONTH}{NUMBER}" ].each do |pattern|
      company.invoice_number_pattern = pattern

      assert company.valid?, "expected #{pattern.inspect} to be valid: #{company.errors.full_messages.to_sentence}"
    end
  end

  test "requires {NUMBER} exactly once in the pattern" do
    [ "INV-{YEAR}", "{NUMBER}-{NUMBER}" ].each do |pattern|
      company = companies(:one)
      company.invoice_number_pattern = pattern

      assert_not company.valid?, "expected #{pattern.inspect} to be invalid"
      assert_includes company.errors[:invoice_number_pattern], "must contain {NUMBER} exactly once"
    end
  end

  test "rejects unknown tags and stray braces in the pattern" do
    [ "INV-{DAY}-{NUMBER}", "INV-{NUMBER", "INV-{NUMBER}}" ].each do |pattern|
      company = companies(:one)
      company.invoice_number_pattern = pattern

      assert_not company.valid?, "expected #{pattern.inspect} to be invalid"
      assert_includes company.errors[:invoice_number_pattern], "can only use the tags {NUMBER}, {YEAR} and {MONTH}"
    end
  end

  test "rejects spaces and file name characters in the pattern" do
    [ "INV {NUMBER}", "INV/{NUMBER}", "INV:{NUMBER}" ].each do |pattern|
      company = companies(:one)
      company.invoice_number_pattern = pattern

      assert_not company.valid?, "expected #{pattern.inspect} to be invalid"
      assert company.errors[:invoice_number_pattern].any? { it.start_with?("can't contain spaces") }
    end
  end

  test "limits minimum digits to between 1 and 10" do
    company = companies(:one)

    [ 0, 11 ].each do |digits|
      company.invoice_number_digits = digits

      assert_not company.valid?, "expected #{digits} digits to be invalid"
    end
  end

  test "keeps the next invoice number within the integer column's range" do
    company = companies(:one)

    company.next_invoice_number = 999_999_999
    assert company.valid?

    company.next_invoice_number = 9_999_999_999
    assert_not company.valid?
    assert_includes company.errors[:next_invoice_number], "must be less than 1000000000"
  end

  test "requires the next number to be above the last sequence used" do
    company = companies(:one)

    company.next_invoice_number = 1
    assert_not company.valid?
    assert_includes company.errors[:next_invoice_number], "must be greater than or equal to 2"

    company.next_invoice_number = 2
    assert company.valid?
  end

  test "stores blank default notes as nil and limits them to 500 characters" do
    company = companies(:one)

    company.default_invoice_notes = "   "
    assert_nil company.default_invoice_notes

    company.default_invoice_notes = "a" * 501
    assert_not company.valid?
    assert_includes company.errors[:default_invoice_notes], "is too long (maximum is 500 characters)"
  end

  test "calls tax documents by the company's name for them" do
    company = companies(:one)
    assert_equal "Tax document", company.tax_document_label

    company.tax_document_name = "  "
    assert_equal "Tax document", company.tax_document_label

    company.tax_document_name = "NF-e"
    assert_equal "NF-e", company.tax_document_label

    company.tax_document_name = "x" * 31
    assert_not company.valid?
  end

  test "database rejects a pattern without {NUMBER}" do
    assert_raises ActiveRecord::StatementInvalid do
      companies(:one).update_column(:invoice_number_pattern, "INV-{YEAR}")
    end
  end
end
