import { Controller } from "@hotwired/stimulus"

const PURPLE = "#9c42e5"

// Chart.js is only downloaded on pages that show a chart, the first time one appears.
let loadingChart

function loadChart() {
  loadingChart ??= import("chart.js").then(({ Chart, registerables }) => {
    Chart.register(...registerables)
    Chart.defaults.font.family = "Inter, ui-sans-serif, system-ui, sans-serif"
    Chart.defaults.color = "#94a3b8"
    return Chart
  })
  return loadingChart
}

// Draws a dashboard chart from data rendered by the server:
// "area" for revenue over time, "bars" for revenue by client.
export default class extends Controller {
  static targets = [ "canvas" ]
  static values = { type: { type: String, default: "area" }, labels: Array, amounts: Array, colors: Array, currency: String }

  async connect() {
    const Chart = await loadChart()
    // The page may have changed while Chart.js was loading.
    if (!this.element.isConnected) return

    this.chart = new Chart(this.canvasTarget, this.typeValue === "bars" ? this.#barsConfig() : this.#areaConfig())
  }

  disconnect() {
    this.chart?.destroy()
  }

  #areaConfig() {
    return {
      type: "line",
      data: {
        labels: this.labelsValue,
        datasets: [ {
          data: this.amountsValue,
          borderColor: PURPLE,
          borderWidth: 2.5,
          backgroundColor: this.#gradient,
          fill: true,
          // Smooth, but never curving below zero between months.
          cubicInterpolationMode: "monotone",
          pointRadius: 0,
          pointHoverRadius: 6,
          pointHoverBackgroundColor: PURPLE,
          pointHoverBorderColor: "#fff",
          pointHoverBorderWidth: 2
        } ]
      },
      options: {
        ...this.#sharedOptions("y"),
        interaction: { mode: "index", intersect: false },
        scales: {
          y: { beginAtZero: true, grid: { color: "#f1f5f9" }, border: { display: false }, ticks: { callback: this.#compactMoney } },
          x: { grid: { display: false }, border: { display: false }, ticks: { maxRotation: 0, autoSkipPadding: 16 } }
        }
      }
    }
  }

  #barsConfig() {
    return {
      type: "bar",
      data: {
        labels: this.labelsValue,
        datasets: [ { data: this.amountsValue, backgroundColor: this.colorsValue, borderRadius: 6, maxBarThickness: 28 } ]
      },
      options: {
        ...this.#sharedOptions("x"),
        indexAxis: "y",
        scales: {
          x: { beginAtZero: true, grid: { color: "#f1f5f9" }, border: { display: false }, ticks: { callback: this.#compactMoney } },
          y: { grid: { display: false }, border: { display: false }, ticks: { color: "#475569", font: { size: 13 } } }
        }
      }
    }
  }

  #sharedOptions(valueAxis) {
    return {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { display: false },
        tooltip: {
          backgroundColor: "rgba(255, 255, 255, 0.95)",
          titleColor: "#94a3b8",
          bodyColor: "#111827",
          bodyFont: { size: 16, weight: "bold" },
          borderColor: "#e5e7eb",
          borderWidth: 1,
          padding: 12,
          cornerRadius: 12,
          displayColors: false,
          callbacks: { label: (context) => this.#money(context.parsed[valueAxis]) }
        }
      }
    }
  }

  #gradient = (context) => {
    const { ctx, chartArea } = context.chart
    if (!chartArea) return null

    const gradient = ctx.createLinearGradient(0, chartArea.top, 0, chartArea.bottom)
    gradient.addColorStop(0, "rgba(156, 66, 229, 0.18)")
    gradient.addColorStop(1, "rgba(156, 66, 229, 0)")
    return gradient
  }

  #compactMoney = (value) => this.#money(value, { notation: "compact" })

  #money(amount, options = {}) {
    return new Intl.NumberFormat("en-US", { style: "currency", currency: this.currencyValue, ...options }).format(amount)
  }
}
