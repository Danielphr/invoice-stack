require "test_helper"

class DevelopmentSeedsTest < ActiveSupport::TestCase
  SEEDS = Rails.root.join("db/seeds/development.rb")

  test "creates a demo account with invoices in every state" do
    load SEEDS

    invoices = User.find_by!(email_address: "demo@example.com").company.invoices

    assert_equal %w[ cancelled draft paid sent ], invoices.distinct.pluck(:status).sort
    assert invoices.any?(&:overdue?)
    assert_equal %w[ USD UYU ], invoices.distinct.pluck(:currency).sort
    assert_equal %w[ fixed hourly ], invoices.distinct.pluck(:billing_type).sort
    assert_operator invoices.count, :>, 20
  end

  test "gives the demo company a logo" do
    load SEEDS

    logo = Company.find_by!(name: "Northwind Studio").logo
    assert logo.attached?
    assert_equal "image/png", logo.content_type
    assert logo.blob.service.exist?(logo.key), "the logo file should be stored, not just its record"
  end

  test "numbers issued invoices in date order" do
    load SEEDS

    issued = User.find_by!(email_address: "demo@example.com").company.invoices.where.not(sequence: nil)

    assert_equal issued.order(:issue_date).ids, issued.order(:sequence).ids
  end

  test "dates invoices in the company's time zone" do
    travel_to Time.utc(2026, 10, 4, 2) do
      load SEEDS
    end

    drafts = User.find_by!(email_address: "demo@example.com").company.invoices.draft
    assert_equal Date.new(2026, 10, 3), drafts.maximum(:issue_date)
  end

  test "does nothing when the demo account already exists" do
    load SEEDS

    assert_no_difference [ "User.count", "Invoice.count" ] do
      load SEEDS
    end
  end
end
