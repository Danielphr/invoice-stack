import { Turbo } from "@hotwired/turbo-rails"

// Shows data-turbo-confirm messages in the app's own dialog. The confirming form can set
// data-confirm-title, data-confirm-button, data-confirm-dismiss and data-confirm-destructive.
const TONES = {
  destructive: { icon: [ "bg-red-50", "text-red-600" ], button: "btn-danger" },
  default: { icon: [ "bg-brand-50", "text-brand-600" ], button: "btn-primary" }
}

Turbo.config.forms.confirm = (message, form) => {
  const dialog = document.getElementById("confirm-dialog")
  if (!dialog) return Promise.resolve(window.confirm(message))

  const { confirmTitle, confirmButton, confirmDismiss, confirmDestructive } = form.dataset
  const tone = confirmDestructive === "true" ? TONES.destructive : TONES.default
  const icon = dialog.querySelector("[data-confirm-icon]")
  const accept = dialog.querySelector("[data-confirm-accept]")

  dialog.querySelector("#confirm-dialog-title").textContent = confirmTitle || "Are you sure?"
  dialog.querySelector("#confirm-dialog-message").textContent = message
  dialog.querySelector("[data-confirm-dismiss]").textContent = confirmDismiss || "Cancel"
  accept.textContent = confirmButton || "Confirm"
  icon.className = [ "flex size-10 shrink-0 items-center justify-center rounded-full", ...tone.icon ].join(" ")
  accept.className = tone.button

  // Escape closes the dialog without setting a value, so clear the previous answer first.
  dialog.returnValue = ""
  dialog.showModal()

  return new Promise((resolve) => {
    dialog.addEventListener("close", () => resolve(dialog.returnValue === "confirm"), { once: true })
  })
}
