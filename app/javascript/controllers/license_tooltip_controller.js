import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["template"]

  connect() {
    this.tooltip = document.createElement("div")
    this.tooltip.className = "license-tooltip-popover"
    this.tooltip.setAttribute("role", "tooltip")
    this.tooltip.hidden = true
    this.tooltip.innerHTML = this.templateTarget.innerHTML

    document.body.appendChild(this.tooltip)

    this.handleViewportChange =
      this.handleViewportChange.bind(this)
  }

  disconnect() {
    this.removeViewportListeners()
    this.tooltip?.remove()
  }

  show() {
    if (!this.tooltip) return

    this.tooltip.hidden = false

    requestAnimationFrame(() => {
      this.positionTooltip()
    })

    window.addEventListener(
      "scroll",
      this.handleViewportChange,
      true
    )

    window.addEventListener(
      "resize",
      this.handleViewportChange
    )
  }

  hide() {
    if (!this.tooltip) return

    this.tooltip.hidden = true
    this.removeViewportListeners()
  }

  handleViewportChange() {
    if (this.tooltip?.hidden) return

    this.positionTooltip()
  }

  positionTooltip() {
    const triggerRect =
      this.element.getBoundingClientRect()

    const tooltipRect =
      this.tooltip.getBoundingClientRect()

    const viewportPadding = 10
    const separation = 10

    let left =
      triggerRect.left +
      triggerRect.width / 2 -
      tooltipRect.width / 2

    left = Math.max(
      viewportPadding,
      Math.min(
        left,
        window.innerWidth -
          tooltipRect.width -
          viewportPadding
      )
    )

    let top =
      triggerRect.top -
      tooltipRect.height -
      separation

    this.tooltip.classList.remove(
      "license-tooltip-popover--below"
    )

    if (top < viewportPadding) {
      top =
        triggerRect.bottom +
        separation

      this.tooltip.classList.add(
        "license-tooltip-popover--below"
      )
    }

    this.tooltip.style.left = `${left}px`
    this.tooltip.style.top = `${top}px`
  }

  removeViewportListeners() {
    window.removeEventListener(
      "scroll",
      this.handleViewportChange,
      true
    )

    window.removeEventListener(
      "resize",
      this.handleViewportChange
    )
  }
}