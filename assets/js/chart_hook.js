import Chart from "chart.js/auto"

const ChartHook = {
  mounted() {
    this.chart = null
    this.renderChart()
  },

  updated() {
    this.renderChart()
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy()
    }
  },

  renderChart() {
    const canvas = this.el.querySelector("canvas")
    if (!canvas) return

    const config = JSON.parse(this.el.dataset.chart)

    if (this.chart) {
      this.chart.destroy()
    }

    config.options = config.options || {}
    config.options.responsive = true
    config.options.maintainAspectRatio = false
    config.options.plugins = config.options.plugins || {}
    config.options.plugins.legend = config.options.plugins.legend || { display: false }
    config.options.scales = config.options.scales || {}

    if (config.options.scales.x) {
      config.options.scales.x.ticks = config.options.scales.x.ticks || {}
      config.options.scales.x.ticks.color = "rgba(255,255,255,0.4)"
      config.options.scales.x.grid = { color: "rgba(255,255,255,0.05)" }
    }

    if (config.options.scales.y) {
      config.options.scales.y.ticks = config.options.scales.y.ticks || {}
      config.options.scales.y.ticks.color = "rgba(255,255,255,0.4)"
      config.options.scales.y.grid = { color: "rgba(255,255,255,0.05)" }
    }

    this.chart = new Chart(canvas, config)
  }
}

export default ChartHook
