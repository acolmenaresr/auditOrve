import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "password",
    "confirmation",
    "lengthRule",
    "uppercaseRule",
    "lowercaseRule",
    "specialRule",
    "matchMessage",
    "submit",
    "passwordToggle",
    "confirmationToggle"
  ]

  connect() {
    this.validate()
  }

  validate() {
    const password = this.passwordTarget.value
    const confirmation = this.confirmationTarget.value

    const hasMinLength =
      password.length >= 8

    const hasUppercase =
      /[A-Z]/.test(password)

    const hasLowercase =
      /[a-z]/.test(password)

    const hasSpecial =
      /[^A-Za-z0-9]/.test(password)

    this.updateRule(
      this.lengthRuleTarget,
      hasMinLength
    )

    this.updateRule(
      this.uppercaseRuleTarget,
      hasUppercase
    )

    this.updateRule(
      this.lowercaseRuleTarget,
      hasLowercase
    )

    this.updateRule(
      this.specialRuleTarget,
      hasSpecial
    )

    const passwordsMatch =
      password.length > 0 &&
      confirmation.length > 0 &&
      password === confirmation

    this.updateMatchMessage(
      confirmation,
      passwordsMatch
    )

    const passwordValid =
      hasMinLength &&
      hasUppercase &&
      hasLowercase &&
      hasSpecial

    this.submitTarget.disabled =
      !(passwordValid && passwordsMatch)
  }

  updateRule(element, valid) {
    element.classList.toggle(
      "password-rule--valid",
      valid
    )

    element.classList.toggle(
      "password-rule--pending",
      !valid
    )

    const icon =
      element.querySelector(
        "[data-password-rule-icon]"
      )

    if (icon) {
      icon.textContent =
        valid ? "✓" : "○"
    }
  }

  updateMatchMessage(
    confirmation,
    matches
  ) {
    const element =
      this.matchMessageTarget

    element.classList.remove(
      "password-match--valid",
      "password-match--invalid",
      "password-match--pending"
    )

    if (confirmation.length === 0) {
      element.textContent =
        "Confirma nuevamente tu contraseña."

      element.classList.add(
        "password-match--pending"
      )

      return
    }

    if (matches) {
      element.textContent =
        "✓ Las contraseñas coinciden."

      element.classList.add(
        "password-match--valid"
      )

      return
    }

    element.textContent =
      "✕ Las contraseñas no coinciden."

    element.classList.add(
      "password-match--invalid"
    )
  }

  togglePassword() {
    this.toggleVisibility(
      this.passwordTarget,
      this.passwordToggleTarget
    )
  }

  toggleConfirmation() {
    this.toggleVisibility(
      this.confirmationTarget,
      this.confirmationToggleTarget
    )
  }

  toggleVisibility(input, button) {
    const willShow =
      input.type === "password"

    input.type =
      willShow ? "text" : "password"

    const eyeShow =
      button.querySelector(
        "[data-eye-show]"
      )

    const eyeHide =
      button.querySelector(
        "[data-eye-hide]"
      )

    if (eyeShow) {
      eyeShow.classList.toggle(
        "is-hidden",
        willShow
      )
    }

    if (eyeHide) {
      eyeHide.classList.toggle(
        "is-hidden",
        !willShow
      )
    }

    button.setAttribute(
      "aria-pressed",
      String(willShow)
    )

    button.setAttribute(
      "aria-label",
      willShow
        ? "Ocultar contraseña"
        : "Mostrar contraseña"
    )
  }
}