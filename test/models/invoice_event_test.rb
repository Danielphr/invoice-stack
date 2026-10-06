require "test_helper"

class InvoiceEventTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    Current.session = @user.sessions.create!
    @draft = invoices(:globex_draft)
    @invoice = invoices(:globex_website)
  end

  test "records who created an invoice and its first status" do
    invoice = companies(:one).invoices.new(client: clients(:globex), currency: "USD", issue_date: Date.current)
    invoice.items.build(description: "Design", quantity: 1, unit_price: 100)
    invoice.save!

    event = invoice.events.sole
    assert_equal [ "created", "draft", @user ], [ event.action, event.to_status, event.user ]
  end

  test "records sending a draft as a status change, not an edit" do
    @draft.update!(status: "sent")

    event = @draft.events.sole
    assert_equal [ "status_changed", "draft", "sent" ], [ event.action, event.from_status, event.to_status ]
  end

  test "records which fields of an issued invoice were edited" do
    @invoice.update!(due_date: @invoice.due_date + 7, items_attributes: [ { id: @invoice.items.first.id, unit_price: 99 } ])

    event = @invoice.events.sole
    assert_equal "edited", event.action
    assert_equal %w[ due_date items ], event.fields
  end

  test "records an uploaded tax document PDF as an edit" do
    @invoice.update!(tax_document_number: "A-1")
    @invoice.update!(tax_document: { io: file_fixture("tax-document.pdf").open, filename: "tax-document.pdf" })

    assert_equal [ %w[ tax_document_number ], %w[ tax_document ] ], @invoice.events.map(&:fields)
  end

  test "doesn't record edits to drafts" do
    @draft.update!(notes: "Updated scope")

    assert_empty @draft.events
  end

  test "records a changed payment date as an edit" do
    @invoice.update!(status: "paid", paid_on: Date.current)
    @invoice.update!(paid_on: Date.current - 1)

    assert_equal [ "status_changed", "edited" ], @invoice.events.map(&:action)
    assert_equal [ "paid_on" ], @invoice.events.last.fields
  end

  test "records archiving and unarchiving" do
    @invoice.update!(status: "paid")
    @invoice.archive
    @invoice.unarchive

    assert_equal %w[ status_changed archived unarchived ], @invoice.events.map(&:action)
  end

  test "can't be changed once recorded" do
    @draft.update!(status: "sent")

    assert_raises(ActiveRecord::ReadOnlyRecord) { @draft.events.sole.update!(action: "edited") }
  end

  test "is deleted with its draft" do
    event = @draft.events.create!(action: "created", to_status: "draft")

    @draft.destroy!

    assert_not InvoiceEvent.exists?(event.id)
  end
end
