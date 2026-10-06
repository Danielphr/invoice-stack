require "application_system_test_case"

class ConfirmDialogTest < ApplicationSystemTestCase
  setup do
    sign_in_as users(:one)
    @draft = invoices(:globex_draft)
  end

  test "asks before sending a draft, and does nothing when dismissed" do
    visit invoice_path(@draft)

    click_on "Mark as sent"
    within "#confirm-dialog" do
      assert_text "Send invoice"
      click_on "Cancel"
    end

    assert_no_selector "#confirm-dialog[open]"
    assert @draft.reload.draft?
  end

  test "sends the draft once confirmed" do
    visit invoice_path(@draft)

    click_on "Mark as sent"
    within("#confirm-dialog") { click_on "Mark as sent" }

    assert_text "marked as sent"
    assert @draft.reload.sent?
  end
end
