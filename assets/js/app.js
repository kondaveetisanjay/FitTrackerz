// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
import ChartHook from "./chart_hook"

const Geolocation = {
  mounted() {
    this.el.addEventListener("click", () => {
      if (navigator.geolocation) {
        this.el.setAttribute("disabled", "true")
        navigator.geolocation.getCurrentPosition(
          (pos) => {
            this.pushEvent("set_location", {
              latitude: pos.coords.latitude,
              longitude: pos.coords.longitude
            })
            this.el.removeAttribute("disabled")
          },
          (_err) => {
            this.pushEvent("location_error", {})
            this.el.removeAttribute("disabled")
          },
          { enableHighAccuracy: true, timeout: 10000 }
        )
      } else {
        this.pushEvent("location_error", {})
      }
    })
  }
}

const BranchGeolocation = {
  mounted() {
    this.el.addEventListener("click", () => {
      if (navigator.geolocation) {
        this.el.setAttribute("disabled", "true")
        this.el.querySelector("span")
        const origText = this.el.textContent.trim()
        this.el.textContent = "Detecting..."
        navigator.geolocation.getCurrentPosition(
          (pos) => {
            const lat = pos.coords.latitude
            const lng = pos.coords.longitude
            // Find and fill the lat/lng inputs in the form
            const form = this.el.closest("form")
            if (form) {
              const latInput = form.querySelector("[name='branch[latitude]']")
              const lngInput = form.querySelector("[name='branch[longitude]']")
              if (latInput) {
                latInput.value = lat.toFixed(6)
                latInput.dispatchEvent(new Event("input", { bubbles: true }))
              }
              if (lngInput) {
                lngInput.value = lng.toFixed(6)
                lngInput.dispatchEvent(new Event("input", { bubbles: true }))
              }
            }
            this.el.removeAttribute("disabled")
            this.el.textContent = "Location set!"
          },
          (_err) => {
            this.el.removeAttribute("disabled")
            this.el.textContent = origText
            alert("Could not detect location. Please allow location access and try again.")
          },
          { enableHighAccuracy: true, timeout: 10000 }
        )
      } else {
        alert("Geolocation is not supported by your browser.")
      }
    })
  }
}

const PlacesAutocomplete = {
  mounted() {
    this._initAttempts = 0
    this._tryInit()
  },
  _tryInit() {
    if (window.google && window.google.maps && window.google.maps.places) {
      this._setup()
    } else if (this._initAttempts < 50) {
      this._initAttempts++
      setTimeout(() => this._tryInit(), 200)
    }
  },
  _setup() {
    const input = this.el
    const autocomplete = new google.maps.places.Autocomplete(input, {
      types: ["establishment", "geocode"],
      fields: ["address_components", "geometry", "name"]
    })

    // Prevent form submission on Enter when selecting a suggestion
    input.addEventListener("keydown", (e) => {
      if (e.key === "Enter") {
        e.preventDefault()
      }
    })

    autocomplete.addListener("place_changed", () => {
      const place = autocomplete.getPlace()
      if (!place.geometry) return

      // Save the display text Google put in the input
      const displayText = input.value

      const components = place.address_components || []
      const get = (type) => {
        const comp = components.find(c => c.types.includes(type))
        return comp ? comp.long_name : ""
      }

      // Build full address: place name + street + area
      const route = get("route")
      const sublocality = get("sublocality_level_1") || get("neighborhood") || get("sublocality")
      let parts = [place.name || ""]
      if (route && !parts[0].includes(route)) parts.push(route)
      if (sublocality && !parts[0].includes(sublocality)) parts.push(sublocality)
      let address = parts.filter(Boolean).join(", ")

      const data = {
        address: address,
        city: get("locality") || get("administrative_area_level_2"),
        state: get("administrative_area_level_1"),
        postal_code: get("postal_code"),
        latitude: place.geometry.location.lat(),
        longitude: place.geometry.location.lng(),
        place_name: place.name || ""
      }

      // Restore the display text after the server re-renders
      this.pushEvent("place_selected", data, () => {
        input.value = displayText
      })
      // Also set it immediately in case of timing issues
      requestAnimationFrame(() => { input.value = displayText })
    })
  }
}

// Google Places Autocomplete for Explore page location search
const ExplorePlacesAutocomplete = {
  mounted() {
    this._initAttempts = 0
    this._tryInit()
  },
  _tryInit() {
    if (window.google && window.google.maps && window.google.maps.places) {
      this._setup()
    } else if (this._initAttempts < 50) {
      this._initAttempts++
      setTimeout(() => this._tryInit(), 200)
    }
  },
  _setup() {
    const input = this.el
    const autocomplete = new google.maps.places.Autocomplete(input, {
      types: ["establishment", "geocode"],
      fields: ["address_components", "geometry", "name"]
    })

    input.addEventListener("keydown", (e) => {
      if (e.key === "Enter") {
        e.preventDefault()
      }
    })

    autocomplete.addListener("place_changed", () => {
      const place = autocomplete.getPlace()
      if (!place.geometry) return

      const displayText = input.value
      const components = place.address_components || []
      const get = (type) => {
        const comp = components.find(c => c.types.includes(type))
        return comp ? comp.long_name : ""
      }

      const data = {
        city: get("locality") || get("administrative_area_level_2"),
        latitude: place.geometry.location.lat(),
        longitude: place.geometry.location.lng(),
        place_name: displayText
      }

      this.pushEvent("place_selected", data)
      requestAnimationFrame(() => { input.value = displayText })
    })
  }
}

const ScrollToBottom = {
  mounted() {
    this.scrollToBottom()
    this.handleEvent("scroll_to_bottom", () => {
      this.scrollToBottom()
    })
  },
  updated() {
    this.scrollToBottom()
  },
  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight
  }
}

const AutoResize = {
  mounted() {
    this.el.addEventListener("input", () => {
      this.el.style.height = "auto"
      this.el.style.height = this.el.scrollHeight + "px"
    })
  }
}

const CsvDownload = {
  mounted() {
    this.handleEvent("download_csv", ({filename, content}) => {
      const blob = new Blob([content], { type: "text/csv;charset=utf-8;" })
      const url = URL.createObjectURL(blob)
      const link = document.createElement("a")
      link.href = url
      link.download = filename
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)
      URL.revokeObjectURL(url)
    })
  }
}

// Password visibility toggle hook
const PasswordVisibilityToggle = {
  mounted() {
    this.addToggleButton()
  },
  updated() {
    // Re-add toggle button if the form re-renders
    if (!this.el.parentElement.querySelector('.password-toggle-btn')) {
      this.addToggleButton()
    }
  },
  addToggleButton() {
    const input = this.el
    const parent = input.parentElement

    // Check if parent is relative positioned
    if (!parent.classList.contains('relative')) {
      parent.classList.add('relative')
    }

    // Create toggle button
    const button = document.createElement('button')
    button.type = 'button'
    button.className = 'password-toggle-btn absolute inset-y-0 right-0 pr-3 flex items-center cursor-pointer'
    button.innerHTML = `
      <svg class="h-5 w-5 text-gray-400 hover:text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path>
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path>
      </svg>
    `

    // Add click handler
    button.addEventListener('click', () => {
      const type = input.getAttribute('type')
      if (type === 'password') {
        input.setAttribute('type', 'text')
        // Change icon to "eye-off"
        button.innerHTML = `
          <svg class="h-5 w-5 text-gray-400 hover:text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21"></path>
          </svg>
        `
      } else {
        input.setAttribute('type', 'password')
        // Change icon back to "eye"
        button.innerHTML = `
          <svg class="h-5 w-5 text-gray-400 hover:text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path>
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path>
          </svg>
        `
      }
    })

    // Append button to parent
    parent.appendChild(button)
  }
}

// Command Palette hook – Cmd+K / Ctrl+K to open, fuzzy filter, keyboard navigation
const CommandPalette = {
  mounted() {
    this.items = JSON.parse(this.el.dataset.items || "[]")
    this.searchInput = document.getElementById(`${this.el.id}-search`)
    this.resultsContainer = document.getElementById(`${this.el.id}-results`)
    this.selectedIndex = 0

    // Global keyboard shortcut
    this._keydownHandler = (e) => {
      if ((e.metaKey || e.ctrlKey) && e.key === "k") {
        e.preventDefault()
        this.toggle()
      }
      if (e.key === "Escape" && !this.el.classList.contains("hidden")) {
        this.close()
      }
    }
    document.addEventListener("keydown", this._keydownHandler)

    // Search filtering
    if (this.searchInput) {
      this.searchInput.addEventListener("input", () => this.filterItems())
      this.searchInput.addEventListener("keydown", (e) => {
        const visible = this.getVisibleItems()
        if (e.key === "ArrowDown") {
          e.preventDefault()
          this.selectedIndex = Math.min(this.selectedIndex + 1, visible.length - 1)
          this.highlightItem(visible)
        } else if (e.key === "ArrowUp") {
          e.preventDefault()
          this.selectedIndex = Math.max(this.selectedIndex - 1, 0)
          this.highlightItem(visible)
        } else if (e.key === "Enter" && visible[this.selectedIndex]) {
          e.preventDefault()
          visible[this.selectedIndex].click()
        }
      })
    }
  },
  destroyed() {
    document.removeEventListener("keydown", this._keydownHandler)
  },
  toggle() {
    if (this.el.classList.contains("hidden")) {
      this.el.classList.remove("hidden")
      this.searchInput && this.searchInput.focus()
      this.selectedIndex = 0
      if (this.searchInput) this.searchInput.value = ""
      this.filterItems()
    } else {
      this.close()
    }
  },
  close() {
    this.el.classList.add("hidden")
  },
  filterItems() {
    const query = (this.searchInput?.value || "").toLowerCase()
    const items = this.resultsContainer?.querySelectorAll(".command-palette-item") || []
    items.forEach(item => {
      const label = item.dataset.label || ""
      item.style.display = label.includes(query) ? "" : "none"
    })
    this.selectedIndex = 0
    this.highlightItem(this.getVisibleItems())
  },
  getVisibleItems() {
    return [...(this.resultsContainer?.querySelectorAll(".command-palette-item") || [])].filter(i => i.style.display !== "none")
  },
  highlightItem(visible) {
    visible.forEach((item, idx) => {
      item.classList.toggle("bg-base-200", idx === this.selectedIndex)
    })
  }
}

// Sidebar collapse hook – persists collapsed state in localStorage
const SidebarCollapse = {
  mounted() {
    const saved = localStorage.getItem("sidebar-collapsed")
    if (saved === "true") {
      this.el.classList.add("sidebar-collapsed")
    }
    this.el.addEventListener("toggle-sidebar", () => {
      this.el.classList.toggle("sidebar-collapsed")
      localStorage.setItem("sidebar-collapsed", this.el.classList.contains("sidebar-collapsed"))
    })
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {Geolocation, BranchGeolocation, PlacesAutocomplete, ExplorePlacesAutocomplete, PasswordVisibilityToggle, ChartHook, ScrollToBottom, AutoResize, CsvDownload, CommandPalette, SidebarCollapse},
})

// Show progress bar on live navigation and form submits – use new primary blue
topbar.config({barColors: {0: "#3B82F6"}, shadowColor: "rgba(0, 0, 0, .15)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// Add password visibility toggle to all password fields
function addPasswordVisibilityToggles() {
  console.log('🔍 Searching for password fields...')

  // Find all password inputs
  const passwordInputs = document.querySelectorAll('input[type="password"]')
  console.log(`Found ${passwordInputs.length} password fields`)

  passwordInputs.forEach((input, index) => {
    // Skip if already has a toggle button
    if (input.dataset.passwordToggleAdded === 'true') {
      console.log(`Password field ${index} already has toggle`)
      return
    }

    console.log(`Adding toggle to password field ${index}`)

    // Mark as processed
    input.dataset.passwordToggleAdded = 'true'

    let parent = input.parentElement
    if (!parent) {
      console.log('No parent element found')
      return
    }

    // Check if we need to wrap the input
    if (!parent.classList.contains('relative') && window.getComputedStyle(parent).position === 'static') {
      // Create a wrapper div
      const wrapper = document.createElement('div')
      wrapper.className = 'relative'
      input.parentNode.insertBefore(wrapper, input)
      wrapper.appendChild(input)
      parent = wrapper
    } else if (window.getComputedStyle(parent).position === 'static') {
      parent.style.position = 'relative'
    }

    // Add padding to input to make room for icon
    input.style.paddingRight = '2.5rem'

    // Create toggle button
    const button = document.createElement('button')
    button.type = 'button'
    button.className = 'password-toggle-btn'
    button.style.cssText = `
      position: absolute;
      top: 50%;
      right: 0;
      transform: translateY(-50%);
      padding-right: 0.75rem;
      display: flex;
      align-items: center;
      cursor: pointer;
      z-index: 10;
      background: none;
      border: none;
      outline: none;
    `
    button.setAttribute('tabindex', '-1')
    button.setAttribute('aria-label', 'Toggle password visibility')

    const eyeIcon = `
      <svg style="width: 1.25rem; height: 1.25rem; color: #9ca3af;" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path>
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"></path>
      </svg>
    `

    const eyeOffIcon = `
      <svg style="width: 1.25rem; height: 1.25rem; color: #9ca3af;" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21"></path>
      </svg>
    `

    button.innerHTML = eyeIcon

    // Add click handler
    button.addEventListener('click', (e) => {
      e.preventDefault()
      e.stopPropagation()
      const currentType = input.getAttribute('type')
      if (currentType === 'password') {
        input.setAttribute('type', 'text')
        button.innerHTML = eyeOffIcon
      } else {
        input.setAttribute('type', 'password')
        button.innerHTML = eyeIcon
      }
    })

    // Add hover effect
    button.addEventListener('mouseenter', () => {
      button.style.opacity = '0.7'
    })
    button.addEventListener('mouseleave', () => {
      button.style.opacity = '1'
    })

    parent.appendChild(button)
    console.log(`✅ Toggle added to password field ${index}`)
  })
}

// Run immediately if DOM is already loaded
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', addPasswordVisibilityToggles)
} else {
  addPasswordVisibilityToggles()
}

// Run after LiveView updates
window.addEventListener('phx:page-loading-stop', () => {
  console.log('LiveView page loading stopped, checking for password fields')
  setTimeout(addPasswordVisibilityToggles, 100)
})

// Use MutationObserver to detect password fields added dynamically
let observerStarted = false
function startObserver() {
  if (observerStarted) return
  observerStarted = true

  const observer = new MutationObserver((mutations) => {
    let shouldCheck = false
    mutations.forEach((mutation) => {
      if (mutation.type === 'childList' && mutation.addedNodes.length > 0) {
        mutation.addedNodes.forEach((node) => {
          if (node.nodeType === 1) {
            if ((node.matches && node.matches('input[type="password"]')) ||
                (node.querySelector && node.querySelector('input[type="password"]'))) {
              shouldCheck = true
            }
          }
        })
      }
    })
    if (shouldCheck) {
      console.log('MutationObserver detected new password field')
      setTimeout(addPasswordVisibilityToggles, 50)
    }
  })

  observer.observe(document.body, {
    childList: true,
    subtree: true
  })
  console.log('MutationObserver started')
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', startObserver)
} else {
  startObserver()
}

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

