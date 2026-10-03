import { Controller } from "@hotwired/stimulus"
import { Chart, registerables } from "chart.js"

Chart.register(...registerables)
Chart.defaults.font.family = "Inter, ui-sans-serif, system-ui, sans-serif"
Chart.defaults.color = "#94a3b8"

const PURPLE = "#9c42e5"

// Draws the revenue area chart from data rendered by the server, one currency at a time.
export default class extends Controller {
  static targets = [ "canvas", "option" ]
  static values = { labels: Array, series: Object, currency: String }

  connect() {
    this.chart = new Chart(this.canvasTarget, {
      type: "line",
      data: {
        labels: this.labelsValue,
        datasets: [ {
          data: this.seriesValue[this.currencyValue],
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
        responsive: true,
        maintainAspectRatio: false,
        interaction: { mode: "index", intersect: false },
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
            callbacks: { label: (context) => this.#money(context.raw) }
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            grid: { color: "#f1f5f9" },
            border: { display: false },
            ticks: { callback: (value) => this.#money(value, { notation: "compact" }) }
          },
          x: {
            grid: { display: false },
            border: { display: false },
            ticks: { maxRotation: 0, autoSkipPadding: 16 }
          }
        }
      }
    })
  }

  disconnect() {
    this.chart?.destroy()
  }

  select({ params: { currency } }) {
    this.currencyValue = currency
  }

  currencyValueChanged() {
    this.optionTargets.forEach((option) => {
      option.setAttribute("aria-pressed", option.dataset.chartCurrencyParam === this.currencyValue)
    })

    if (this.chart) {
      this.chart.data.datasets[0].data = this.seriesValue[this.currencyValue]
      this.chart.update()
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

  #money(amount, options = {}) {
    return new Intl.NumberFormat("en-US", { style: "currency", currency: this.currencyValue, ...options }).format(amount)
  }
}
