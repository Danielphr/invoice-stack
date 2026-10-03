import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "zone", "input", "preview", "placeholder" ]

  highlight(event) {
    event.preventDefault()
    this.zoneTarget.classList.add("border-brand-500", "bg-brand-50")
  }

  unhighlight() {
    this.zoneTarget.classList.remove("border-brand-500", "bg-brand-50")
  }

  drop(event) {
    event.preventDefault()
    this.unhighlight()

    const file = event.dataTransfer.files[0]
    if (!file) return

    const files = new DataTransfer()
    files.items.add(file)
    this.inputTarget.files = files.files
    this.preview()
  }

  preview() {
    const file = this.inputTarget.files[0]
    if (!file || !file.type.startsWith("image/")) return

    URL.revokeObjectURL(this.previewTarget.src)
    this.previewTarget.src = URL.createObjectURL(file)
    this.previewTarget.hidden = false
    this.placeholderTarget.hidden = true
  }
}
