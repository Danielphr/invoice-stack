import { Controller } from "@hotwired/stimulus"

// Opens a <dialog> as a modal. Set the open value to show it right away, for example
// when a form inside it comes back with errors.
export default class extends Controller {
  static targets = [ "dialog" ]
  static values = { open: Boolean }

  connect() {
    if (this.openValue) this.open()
  }

  open() {
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }
}
