import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "action",
    "exceptionToggle",
    "exceptionFields",
    "exceptionReason",
    "submit"
  ]

  connect() {
    this.toggle()
    this.syncSubmitLabel()
  }

  toggle() {
    const enabled =
      this.hasExceptionToggleTarget &&
      this.exceptionToggleTarget.checked

    if (this.hasExceptionFieldsTarget) {
      this.exceptionFieldsTarget.hidden = !enabled
    }

    if (this.hasExceptionReasonTarget) {
      this.exceptionReasonTarget.disabled = !enabled
      this.exceptionReasonTarget.required = enabled

      if (!enabled) {
        this.exceptionReasonTarget.value = ""
      }
    }
  }

  syncSubmitLabel() {
    if (!this.hasSubmitTarget) {
      return
    }

    this.submitTarget.value =
      this.selectedAction() === "comentario" ?
        "Guardar comentario" :
        "Terminar alerta"
  }

  selectedAction() {
    if (!this.hasActionTarget) {
      return "comentario"
    }

    return this.actionTarget.value
  }
}
