import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "action",
    "comment",
    "exceptionToggle",
    "exceptionFields",
    "exceptionReason",
    "submit"
  ]

  connect() {
    this.toggle()
    this.syncSubmitLabel()
    this.syncSubmitState()
  }

  toggle() {
    const enabled = this.exceptionEnabled()

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

    this.syncSubmitState()
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

  syncSubmitState() {
    if (!this.hasSubmitTarget) {
      return
    }

    this.submitTarget.disabled = !this.canSubmit()
  }

  canSubmit() {
    if (!this.hasComment()) {
      return false
    }

    if (!this.exceptionEnabled()) {
      return true
    }

    return this.hasExceptionReason()
  }

  hasComment() {
    return this.hasCommentTarget &&
      this.commentTarget.value.trim().length > 0
  }

  hasExceptionReason() {
    return this.hasExceptionReasonTarget &&
      this.exceptionReasonTarget.value.trim().length > 0
  }

  exceptionEnabled() {
    return this.hasExceptionToggleTarget &&
      this.exceptionToggleTarget.checked
  }

  selectedAction() {
    if (!this.hasActionTarget) {
      return "comentario"
    }

    return this.actionTarget.value
  }
}
