import "@hotwired/turbo-rails"
import "controllers"

const SEARCHABLE_SELECT_SELECTOR = ".js-searchable-select"

function initializeSearchableSelect(select) {
  if (select.tomselect) return

  const TomSelect = window.TomSelect

  if (typeof TomSelect !== "function") {
    console.error(
      "Tom Select no está disponible. Revisa la carga de tom-select.complete.min.js"
    )

    return
  }

  new TomSelect(select, {
    create: false,
    maxItems: 1,
    maxOptions: null,

    allowEmptyOption: true,
    openOnFocus: true,
    closeAfterSelect: true,
    hideSelected: true,

    highlight: true,
    refreshThrottle: 0,
    selectOnTab: false,

    searchField: ["text"],
    searchConjunction: "and",

    placeholder:
      select.dataset.placeholder ||
      "Escribe para buscar",

    sortField: [
      {
        field: "$score",
        direction: "desc"
      },
      {
        field: "text",
        direction: "asc"
      }
    ],

    onInitialize() {
      const instance = this
      const input = instance.control_input

      input.setAttribute("autocomplete", "off")
      input.setAttribute("spellcheck", "false")
      input.setAttribute("aria-autocomplete", "list")

      /*
       * Si existe una opción seleccionada, la primera tecla:
       * 1. elimina la selección;
       * 2. se conserva como texto buscado;
       * 3. actualiza las coincidencias.
       */
      input.addEventListener("keydown", (event) => {
        const isPrintableKey =
          event.key.length === 1 &&
          !event.ctrlKey &&
          !event.metaKey &&
          !event.altKey

        const isDeleteKey =
          event.key === "Backspace" ||
          event.key === "Delete"

        if (instance.items.length === 0) return
        if (!isPrintableKey && !isDeleteKey) return

        event.preventDefault()

        const query = isPrintableKey
          ? event.key
          : ""

        instance.clear(true)
        instance.setTextboxValue(query)
        instance.refreshOptions(true)
        instance.control_input.focus()
      })
    },

    onType() {
      /*
       * Tom Select filtra automáticamente por searchField.
       * Se fuerza el refresco inmediato del desplegable.
       */
      this.refreshOptions(true)
    },

    onDropdownOpen() {
      this.control_input.focus()
    },

    render: {
      no_results() {
        return `
          <div class="no-results">
            No se encontraron resultados
          </div>
        `
      }
    }
  })
}

function initializeSearchableSelects() {
  document
    .querySelectorAll(SEARCHABLE_SELECT_SELECTOR)
    .forEach((select) => {
      initializeSearchableSelect(select)
    })
}

document.addEventListener(
  "turbo:load",
  initializeSearchableSelects
)

document.addEventListener("turbo:before-cache", () => {
  document
    .querySelectorAll(SEARCHABLE_SELECT_SELECTOR)
    .forEach((select) => {
      select.tomselect?.destroy()
    })
})