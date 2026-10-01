import { Controller } from "@hotwired/stimulus"

// Slides the sidebar in and out on small screens. On large screens the
// sidebar is always visible and these classes have no effect.
export default class extends Controller {
  static targets = [ "panel", "backdrop", "toggle" ]

  open() {
    this.#setOpen(true)
  }

  close() {
    this.#setOpen(false)
  }

  #setOpen(open) {
    this.panelTarget.classList.toggle("-translate-x-full", !open)
    this.backdropTarget.classList.toggle("hidden", !open)
    this.toggleTarget.setAttribute("aria-expanded", open)
  }
}
