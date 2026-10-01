import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input", "button", "showIcon", "hideIcon" ]

  toggle() {
    const reveal = this.inputTarget.type === "password"

    this.inputTarget.type = reveal ? "text" : "password"
    this.buttonTarget.setAttribute("aria-pressed", reveal)
    this.showIconTarget.classList.toggle("hidden", reveal)
    this.hideIconTarget.classList.toggle("hidden", !reveal)
  }
}
