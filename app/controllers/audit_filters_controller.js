import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["period", "customField"]

  connect() {
    this.toggleCustomDates()
  }

  toggleCustomDates() {
    const isCustom = this.periodTarget.value === "custom"

    this.customFieldTargets.forEach((field) => {
      field.hidden = !isCustom

      field.querySelectorAll("input").forEach((input) => {
        input.disabled = !isCustom
      })
    })
  }
}