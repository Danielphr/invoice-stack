import { Controller } from "@hotwired/stimulus"

// Adds and removes item rows, keeps the item column labels in sync with the
// billing type and previews totals. The server recalculates everything on save.
export default class extends Controller {
  static targets = [ "items", "item", "template", "destroy", "quantity", "unitPrice", "amount",
    "discount", "subtotal", "total", "currency", "quantityLabel", "unitPriceLabel" ]
  static values = { labels: Object }

  connect() {
    this.recalculate()
  }

  addItem() {
    const html = this.templateTarget.innerHTML.replaceAll("NEW_ITEM", Date.now().toString())
    this.itemsTarget.insertAdjacentHTML("beforeend", html)
    this.recalculate()
  }

  removeItem(event) {
    const row = event.target.closest("[data-invoice-form-target='item']")
    const destroy = row.querySelector("[data-invoice-form-target='destroy']")
    const persisted = row.querySelector("input[name$='[id]']").value !== ""

    if (persisted) {
      destroy.value = "1"
      row.hidden = true
      row.querySelectorAll("[required]").forEach(input => input.required = false)
    } else {
      row.remove()
    }
    this.recalculate()
  }

  updateLabels(event) {
    const labels = this.labelsValue[event.target.value]
    this.quantityLabelTarget.textContent = labels.quantity
    this.unitPriceLabelTarget.textContent = labels.unit_price
  }

  recalculate() {
    let subtotal = 0

    this.itemTargets.filter(row => !row.hidden).forEach(row => {
      const quantity = parseFloat(row.querySelector("[data-invoice-form-target='quantity']").value) || 0
      const unitPrice = parseFloat(row.querySelector("[data-invoice-form-target='unitPrice']").value) || 0
      const amount = Math.round(quantity * unitPrice * 100) / 100

      row.querySelector("[data-invoice-form-target='amount']").textContent = this.#format(amount)
      subtotal += amount
    })

    const discount = parseFloat(this.discountTarget.value) || 0
    this.subtotalTarget.textContent = this.#format(subtotal)
    this.totalTarget.textContent = this.#format(subtotal - discount)
  }

  #format(amount) {
    return new Intl.NumberFormat("en-US", { style: "currency", currency: this.currencyTarget.value }).format(amount)
  }
}
