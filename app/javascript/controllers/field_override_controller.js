import { Controller } from "@hotwired/stimulus"

// Unlocks a read-only field when the user explicitly chooses to override it,
// and shows a warning about the consequences.
export default class extends Controller {
  static targets = [ "input", "button", "warning" ]

  unlock() {
    this.inputTarget.readOnly = false
    this.inputTarget.focus()
    this.buttonTarget.hidden = true
    this.warningTarget.hidden = false
  }
}
