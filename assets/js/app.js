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

// ============================================================
// Animation Hooks — Scroll Reveal, Counters, Stagger, Page Transitions
// ============================================================

// Easing function for counter animations
function easeOutExpo(t) {
  return t === 1 ? 1 : 1 - Math.pow(2, -10 * t)
}

// ScrollReveal — IntersectionObserver-based scroll animations
// Add class="reveal" (or reveal-scale, reveal-left, reveal-right) to elements.
// They get .revealed when in view, lose it when out — so the keyframe
// pop animation REPLAYS every time you scroll them back in.
const ScrollReveal = {
  mounted() {
    this._observeElements()
  },
  updated() {
    // Re-observe new elements after LiveView DOM updates
    this._observeElements()
  },
  destroyed() {
    if (this._observer) this._observer.disconnect()
  },
  _observeElements() {
    if (this._observer) this._observer.disconnect()

    const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    if (prefersReducedMotion) {
      this.el.querySelectorAll('.reveal, .reveal-scale, .reveal-left, .reveal-right').forEach(el => {
        el.classList.add('revealed')
      })
      return
    }

    this._observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          // Force a reflow so the animation restarts even if class flicker is fast
          entry.target.classList.remove('revealed')
          // eslint-disable-next-line no-unused-expressions
          void entry.target.offsetWidth
          entry.target.classList.add('revealed')
        } else {
          // Element scrolled out of view → reset so it can pop back in
          entry.target.classList.remove('revealed')
        }
      })
    }, {
      threshold: 0.12,
      rootMargin: '0px 0px -60px 0px'
    })

    this.el.querySelectorAll('.reveal, .reveal-scale, .reveal-left, .reveal-right').forEach(el => {
      this._observer.observe(el)
    })
  }
}

// AnimatedCounter — animates a number from 0 to data-target
// Usage: <span id="counter-1" phx-hook="AnimatedCounter" data-target="248">0</span>
const AnimatedCounter = {
  mounted() {
    this._animate()
  },
  updated() {
    // Re-animate if data-target changes
    const newTarget = parseInt(this.el.dataset.target, 10)
    if (newTarget !== this._lastTarget) {
      this._animate()
    }
  },
  _animate() {
    const target = parseInt(this.el.dataset.target, 10)
    if (isNaN(target)) return
    this._lastTarget = target

    const duration = 800
    const start = performance.now()
    const suffix = this.el.dataset.suffix || ''
    const prefix = this.el.dataset.prefix || ''

    // Only animate when visible
    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          observer.unobserve(this.el)
          this._runAnimation(target, duration, start, prefix, suffix)
        }
      })
    }, { threshold: 0.3 })

    observer.observe(this.el)
  },
  _runAnimation(target, duration, start, prefix, suffix) {
    const step = (now) => {
      const elapsed = now - start
      const progress = Math.min(elapsed / duration, 1)
      const value = Math.round(easeOutExpo(progress) * target)
      this.el.textContent = prefix + value.toLocaleString() + suffix

      if (progress < 1) {
        requestAnimationFrame(step)
      } else {
        this.el.classList.add('counter-done')
        // Remove the class after animation completes so it can replay
        setTimeout(() => this.el.classList.remove('counter-done'), 300)
      }
    }
    requestAnimationFrame(step)
  }
}

// StaggerChildren — applies staggered --reveal-delay to child .reveal elements
// Usage: <div id="grid-1" phx-hook="StaggerChildren" data-stagger="60">
const StaggerChildren = {
  mounted() {
    this._applyStagger()
  },
  updated() {
    this._applyStagger()
  },
  _applyStagger() {
    const staggerMs = parseInt(this.el.dataset.stagger || '60', 10)
    const children = this.el.querySelectorAll('.reveal, .reveal-scale, .reveal-left, .reveal-right')
    children.forEach((child, i) => {
      child.style.setProperty('--reveal-delay', `${i * staggerMs}ms`)
    })
  }
}

// PageTransition — adds page-enter animation on mount
// Usage: <main id="main-content" phx-hook="PageTransition">
const PageTransition = {
  mounted() {
    this.el.classList.add('page-enter')
    // Clean up class after animation to avoid re-triggering on updates
    this.el.addEventListener('animationend', () => {
      this.el.classList.remove('page-enter')
    }, { once: true })
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {
    Geolocation, BranchGeolocation, PlacesAutocomplete,
    ExplorePlacesAutocomplete, PasswordVisibilityToggle,
    ScrollReveal, AnimatedCounter, StaggerChildren, PageTransition
  },
})

// Show progress bar on live navigation and form submits
// Using brand primary indigo color
topbar.config({barColors: {0: "#4338ca", 0.5: "#6366f1", 1.0: "#818cf8"}, shadowColor: "rgba(67, 56, 202, .2)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(200))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// ============================================================
// Smooth wheel scroll — lerps the window scrollTop toward a
// target updated by wheel events. Doesn't hijack keyboard,
// touch, anchor links, or nested scroll containers.
// ============================================================
;(function smoothWheelScroll() {
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return
  // Most touch devices already scroll smoothly; only intercept wheel input.
  const ua = navigator.userAgent
  if (/Mobi|Android|iP(hone|ad|od)/.test(ua)) return

  const EASE = 0.12          // 0..1, higher = snappier
  const MULT = 1.0           // wheel sensitivity multiplier
  const SETTLE = 0.4         // px threshold to stop the loop

  let target = window.scrollY
  let current = window.scrollY
  let raf = null
  let lastTs = performance.now()

  function maxScroll() {
    return Math.max(0, document.documentElement.scrollHeight - window.innerHeight)
  }

  function tick(ts) {
    const dt = Math.min(64, ts - lastTs) / 16.6667 // frames @60Hz
    lastTs = ts
    const ease = 1 - Math.pow(1 - EASE, dt)
    current += (target - current) * ease
    if (Math.abs(target - current) < SETTLE) {
      current = target
      window.scrollTo(0, current)
      raf = null
      return
    }
    window.scrollTo(0, current)
    raf = requestAnimationFrame(tick)
  }

  function onWheel(e) {
    // Skip if user is over a nested scrollable (modals, dropdowns, code blocks)
    let n = e.target
    while (n && n !== document.body) {
      if (n.scrollHeight > n.clientHeight) {
        const cs = getComputedStyle(n)
        if (/(auto|scroll|overlay)/.test(cs.overflowY)) return
      }
      n = n.parentElement
    }
    // Skip ctrl-wheel (zoom) and pinch
    if (e.ctrlKey) return

    e.preventDefault()
    target = Math.max(0, Math.min(maxScroll(), target + e.deltaY * MULT))
    if (!raf) {
      lastTs = performance.now()
      raf = requestAnimationFrame(tick)
    }
  }

  // Resync on direct scroll (keyboard, scrollbar, anchor, programmatic)
  function onScroll() {
    if (raf) return // animating — let lerp finish
    target = current = window.scrollY
  }

  window.addEventListener('wheel', onWheel, { passive: false })
  window.addEventListener('scroll', onScroll, { passive: true })
  // Resync target after navigation
  window.addEventListener('phx:page-loading-stop', () => {
    target = current = window.scrollY
    if (raf) { cancelAnimationFrame(raf); raf = null }
  })
})()

// ============================================================
// Global Scroll Reveal — works on static (controller) pages too.
// Pop animation REPLAYS every time the element scrolls into view.
// Single shared observer so we don't double-attach when LiveView
// re-runs this on navigation.
// ============================================================
let __globalRevealObserver = null

function initGlobalScrollReveal() {
  const REVEAL_BASE_SELECTOR = '.reveal, .reveal-scale, .reveal-left, .reveal-right'

  const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches
  if (prefersReducedMotion) {
    document.querySelectorAll(REVEAL_BASE_SELECTOR).forEach(el => el.classList.add('revealed'))
    return
  }

  // Auto-stagger any grid/container marked with [data-auto-stagger]
  document.querySelectorAll('[data-auto-stagger]').forEach(container => {
    const ms = parseInt(container.dataset.autoStagger || '70', 10)
    container.querySelectorAll(':scope > .reveal, :scope > .reveal-scale, :scope > .reveal-left, :scope > .reveal-right')
      .forEach((child, i) => child.style.setProperty('--reveal-delay', `${i * ms}ms`))
  })

  // Build (or reuse) a single observer
  if (!__globalRevealObserver) {
    __globalRevealObserver = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        const el = entry.target
        if (entry.isIntersecting) {
          // Reflow trick → animation re-runs from frame 0 each time
          el.classList.remove('revealed')
          // eslint-disable-next-line no-unused-expressions
          void el.offsetWidth
          el.classList.add('revealed')
        } else {
          el.classList.remove('revealed')
        }
      })
    }, {
      threshold: 0.12,
      rootMargin: '0px 0px -60px 0px'
    })
  }

  // Observe every reveal element (idempotent — observe() on the same node is a no-op)
  document.querySelectorAll(REVEAL_BASE_SELECTOR).forEach(el => __globalRevealObserver.observe(el))

  // Auto-tag common card elements that don't already opt in
  const AUTO_REVEAL_SELECTORS = ['.glass-card', '.surface-2', '.surface-3', '.stat-card']
  document.querySelectorAll(AUTO_REVEAL_SELECTORS.join(','))
    .forEach(el => {
      // Skip absolute / fixed positioned elements (orbit badges, decorative blobs)
      const cs = window.getComputedStyle(el)
      if (cs.position === 'absolute' || cs.position === 'fixed') return

      if (
        !el.classList.contains('reveal') &&
        !el.classList.contains('reveal-scale') &&
        !el.classList.contains('reveal-left') &&
        !el.classList.contains('reveal-right')
      ) {
        el.classList.add('reveal')
        __globalRevealObserver.observe(el)
      }
    })
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initGlobalScrollReveal)
} else {
  initGlobalScrollReveal()
}

// Re-run on LiveView navigation so newly arrived static pages also animate
window.addEventListener('phx:page-loading-stop', () => {
  requestAnimationFrame(initGlobalScrollReveal)
})

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

