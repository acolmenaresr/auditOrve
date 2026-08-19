import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  submit(event) {
    if (!event.target.value) {
      return
    }

    this.element.requestSubmit()
  }
}
