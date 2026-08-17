import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "trigger",
    "menu"
  ]

  connect() {
    this.boundOutsideClick =
      this.handleOutsideClick.bind(this)

    this.boundKeydown =
      this.handleKeydown.bind(this)

    document.addEventListener(
      "click",
      this.boundOutsideClick
    )

    document.addEventListener(
      "keydown",
      this.boundKeydown
    )
  }

  disconnect() {
    document.removeEventListener(
      "click",
      this.boundOutsideClick
    )

    document.removeEventListener(
      "keydown",
      this.boundKeydown
    )
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    if (this.isOpen()) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    if (
      !this.hasMenuTarget ||
      !this.hasTriggerTarget
    ) {
      return
    }

    this.menuTarget.hidden = false

    this.element.classList.add(
      "is-open"
    )

    this.triggerTarget.setAttribute(
      "aria-expanded",
      "true"
    )
  }

  close() {
    if (
      !this.hasMenuTarget ||
      !this.hasTriggerTarget
    ) {
      return
    }

    this.menuTarget.hidden = true

    this.element.classList.remove(
      "is-open"
    )

    this.triggerTarget.setAttribute(
      "aria-expanded",
      "false"
    )
  }

  handleOutsideClick(event) {
    if (!this.isOpen()) {
      return
    }

    if (
      this.element.contains(
        event.target
      )
    ) {
      return
    }

    this.close()
  }

  handleKeydown(event) {
    if (
      event.key !== "Escape" ||
      !this.isOpen()
    ) {
      return
    }

    this.close()

    if (this.hasTriggerTarget) {
      this.triggerTarget.focus()
    }
  }

  isOpen() {
    return (
      this.hasMenuTarget &&
      this.menuTarget.hidden === false
    )
  }
}