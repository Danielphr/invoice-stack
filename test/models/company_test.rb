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

  test "database rejects a pattern without {NUMBER}" do
    assert_raises ActiveRecord::StatementInvalid do
      companies(:one).update_column(:invoice_number_pattern, "INV-{YEAR}")
    end
  end
end
