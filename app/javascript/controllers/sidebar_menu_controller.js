import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "group",
    "submenu"
  ]

  connect() {
    this.openTouchGroup = null

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
    /*
     * Desktop:
     * el menú funciona exclusivamente por hover.
     *
     * Evitamos que un click deje el panel fijado.
     */
    if (this.deviceSupportsHover()) {
      return
    }

    event.preventDefault()
    event.stopPropagation()

    const group =
      event.currentTarget.closest(
        "[data-sidebar-menu-target='group']"
      )

    if (!group) {
      return
    }

    if (this.openTouchGroup === group) {
      this.closeGroup(group)
      this.openTouchGroup = null
      return
    }

    this.closeAllGroups()

    group.classList.add("is-open")

    this.setExpanded(
      group,
      true
    )

    this.openTouchGroup = group
  }

  mouseenter(event) {
    if (!this.deviceSupportsHover()) {
      return
    }

    const group =
      event.currentTarget.closest(
        "[data-sidebar-menu-target='group']"
      )

    if (!group) {
      return
    }

    /*
     * Cierra cualquier otro estado residual.
     */
    this.groupTargets.forEach(
      (otherGroup) => {
        if (otherGroup === group) {
          return
        }

        otherGroup.classList.remove(
          "is-open"
        )

        this.setExpanded(
          otherGroup,
          false
        )
      }
    )

    group.classList.add(
      "is-open"
    )

    this.setExpanded(
      group,
      true
    )
  }

  mouseleave(event) {
    if (!this.deviceSupportsHover()) {
      return
    }

    const group =
      event.currentTarget.closest(
        "[data-sidebar-menu-target='group']"
      )

    if (!group) {
      return
    }

    /*
     * Pequeño retraso para permitir que el cursor
     * atraviese del botón al submenu.
     */
    window.setTimeout(() => {
      if (group.matches(":hover")) {
        return
      }

      this.closeGroup(group)
    }, 80)
  }

  submenuMouseenter(event) {
    if (!this.deviceSupportsHover()) {
      return
    }

    const group =
      event.currentTarget.closest(
        "[data-sidebar-menu-target='group']"
      )

    if (!group) {
      return
    }

    group.classList.add(
      "is-open"
    )

    this.setExpanded(
      group,
      true
    )
  }

  submenuMouseleave(event) {
    if (!this.deviceSupportsHover()) {
      return
    }

    const group =
      event.currentTarget.closest(
        "[data-sidebar-menu-target='group']"
      )

    if (!group) {
      return
    }

    window.setTimeout(() => {
      if (group.matches(":hover")) {
        return
      }

      this.closeGroup(group)
    }, 80)
  }

  handleOutsideClick(event) {
    if (this.deviceSupportsHover()) {
      return
    }

    if (!this.openTouchGroup) {
      return
    }

    if (
      this.element.contains(
        event.target
      )
    ) {
      return
    }

    this.closeAllGroups()
  }

  handleKeydown(event) {
    if (event.key !== "Escape") {
      return
    }

    this.closeAllGroups()
  }

  closeGroup(group) {
    if (!group) {
      return
    }

    group.classList.remove(
      "is-open"
    )

    this.setExpanded(
      group,
      false
    )
  }

  closeAllGroups() {
    this.groupTargets.forEach(
      (group) => {
        this.closeGroup(group)
      }
    )

    this.openTouchGroup = null
  }

  setExpanded(group, expanded) {
    const trigger =
      group.querySelector(
        ".app-sidebar__main-button"
      )

    if (!trigger) {
      return
    }

    trigger.setAttribute(
      "aria-expanded",
      expanded ? "true" : "false"
    )
  }

  deviceSupportsHover() {
    return window.matchMedia(
      "(hover: hover) and (pointer: fine)"
    ).matches
  }
}