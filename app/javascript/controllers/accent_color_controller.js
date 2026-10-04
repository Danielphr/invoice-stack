import { Controller } from "@hotwired/stimulus"

// Exposes the company's accent color as the --accent CSS variable.
// Setting it from JavaScript rather than a style attribute keeps the page
// working under a Content Security Policy that blocks inline styles.
export default class extends Controller {
  static values = { color: String }

  colorValueChanged() {
    this.element.style.setProperty("--accent", this.colorValue)
  }
}
