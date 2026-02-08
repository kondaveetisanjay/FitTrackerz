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
import {hooks as colocatedHooks} from "phoenix-colocated/fitconnex"
import topbar from "../vendor/topbar"

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

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, Geolocation, BranchGeolocation, PlacesAutocomplete},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

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

