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

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

// Chart color schemes for portfolio pie charts
const colorSchemes = [
  ['rgb(59, 130, 246)', 'rgb(239, 68, 68)', 'rgb(16, 185, 129)', 'rgb(249, 115, 22)', 'rgb(147, 51, 234)', 'rgb(6, 182, 212)', 'rgb(236, 72, 153)', 'rgb(251, 191, 36)', 'rgb(99, 102, 241)', 'rgb(20, 184, 166)'],
  ['rgb(239, 68, 68)', 'rgb(249, 115, 22)', 'rgb(251, 191, 36)', 'rgb(245, 158, 11)', 'rgb(252, 211, 77)', 'rgb(234, 88, 12)', 'rgb(220, 38, 38)', 'rgb(248, 113, 113)', 'rgb(251, 146, 60)', 'rgb(252, 165, 165)'],
  ['rgb(16, 185, 129)', 'rgb(5, 150, 105)', 'rgb(6, 182, 212)', 'rgb(20, 184, 166)', 'rgb(14, 165, 233)', 'rgb(34, 211, 238)', 'rgb(52, 211, 153)', 'rgb(45, 212, 191)', 'rgb(125, 211, 252)', 'rgb(103, 232, 249)'],
  ['rgb(236, 72, 153)', 'rgb(219, 39, 119)', 'rgb(244, 114, 182)', 'rgb(251, 113, 133)', 'rgb(190, 24, 93)', 'rgb(249, 168, 212)', 'rgb(251, 207, 232)', 'rgb(225, 29, 72)', 'rgb(190, 18, 60)', 'rgb(244, 63, 94)'],
  ['rgb(217, 119, 6)', 'rgb(146, 64, 14)', 'rgb(180, 83, 9)', 'rgb(120, 53, 15)', 'rgb(202, 138, 4)', 'rgb(161, 98, 7)', 'rgb(245, 158, 11)', 'rgb(251, 191, 36)', 'rgb(252, 211, 77)', 'rgb(253, 224, 71)'],
  ['rgb(71, 85, 105)', 'rgb(100, 116, 139)', 'rgb(148, 163, 184)', 'rgb(51, 65, 85)', 'rgb(30, 41, 59)', 'rgb(15, 23, 42)', 'rgb(203, 213, 225)', 'rgb(226, 232, 240)', 'rgb(241, 245, 249)', 'rgb(248, 250, 252)']
];

const dividendColors = [
  'rgb(59, 130, 246)', 'rgb(16, 185, 129)', 'rgb(249, 115, 22)',
  'rgb(236, 72, 153)', 'rgb(147, 51, 234)', 'rgb(6, 182, 212)',
  'rgb(251, 191, 36)', 'rgb(239, 68, 68)', 'rgb(99, 102, 241)', 'rgb(20, 184, 166)'
];

function currencyFormatter(currency, minimumFractionDigits = 2, maximumFractionDigits = 2) {
  return function(value) {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: currency,
      minimumFractionDigits: minimumFractionDigits,
      maximumFractionDigits: maximumFractionDigits
    }).format(value);
  };
}

let Hooks = {};

Hooks.ChartInit = {
  mounted() {
    this._createChart();
  },
  updated() {
    if (this._chart) {
      this._chart.destroy();
      this._chart = null;
    }
    this._createChart();
  },
  destroyed() {
    if (this._chart) {
      this._chart.destroy();
    }
  },
  _createChart() {
    if (typeof Chart === 'undefined') return;

    const chartType = this.el.dataset.chartType;
    const chartData = JSON.parse(this.el.dataset.chartData);
    const currency = this.el.dataset.currency;

    switch (chartType) {
      case 'portfolio-pie':
        this._createPortfolioPie(chartData, currency);
        break;
      case 'portfolio-value':
        this._createPortfolioValue(chartData, currency);
        break;
      case 'dividend-bar':
        this._createDividendBar(chartData, currency);
        break;
      case 'investment-allocation':
        this._createInvestmentAllocation(chartData, currency);
        break;
    }
  },
  _createPortfolioPie(data, currency) {
    const labels = data.map(item => item.label);
    const values = data.map(item => item.value);
    const colorIndex = parseInt(this.el.dataset.colorIndex) || 0;
    const colors = colorSchemes[colorIndex % colorSchemes.length];
    const format = currencyFormatter(currency);
    const total = values.reduce((a, b) => a + b, 0);
    const percentageOf = (value) => ((value / total) * 100).toFixed(1) + '%';

    this._chart = new Chart(this.el, {
      type: 'pie',
      data: {
        labels: labels,
        datasets: [{
          data: values,
          backgroundColor: colors.slice(0, labels.length),
          borderWidth: 2,
          borderColor: '#fff'
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        layout: { padding: { top: 20, bottom: 20, left: 20, right: 20 } },
        plugins: {
          legend: { display: false },
          tooltip: {
            displayColors: false,
            callbacks: {
              title: function(context) { return context[0].label; },
              label: function(context) {
                return format(context.parsed) + ' (' + percentageOf(context.parsed) + ')';
              }
            }
          },
          datalabels: {
            color: '#1f2937',
            font: { weight: 'bold', size: 10 },
            anchor: 'end',
            align: 'start',
            offset: 8,
            clamp: false,
            padding: { top: 2, bottom: 2, left: 4, right: 4 },
            display: function(context) {
              return parseFloat(percentageOf(context.dataset.data[context.dataIndex])) >= 5;
            },
            formatter: function(value, context) {
              const label = context.chart.data.labels[context.dataIndex];
              return label + '\n' + percentageOf(value);
            }
          }
        }
      },
      plugins: [ChartDataLabels]
    });
  },
  _createPortfolioValue(snapshots, currency) {
    const labels = snapshots.map(s => s.snapshot_date);
    const values = snapshots.map(s => parseFloat(s.total_value.amount));
    const format = currencyFormatter(currency);
    const formatShort = currencyFormatter(currency, 0, 0);

    this._chart = new Chart(this.el, {
      type: 'line',
      data: {
        labels: labels,
        datasets: [{
          label: 'Portfolio Value',
          data: values,
          borderColor: 'rgb(16, 185, 129)',
          backgroundColor: 'rgba(16, 185, 129, 0.1)',
          borderWidth: 2,
          fill: true,
          tension: 0.3,
          pointRadius: 3,
          pointHoverRadius: 5,
          pointBackgroundColor: 'rgb(16, 185, 129)',
          pointBorderColor: '#fff',
          pointBorderWidth: 2
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: { mode: 'index', intersect: false },
        plugins: {
          legend: { display: false },
          tooltip: {
            displayColors: false,
            callbacks: {
              title: function(context) { return context[0].label; },
              label: function(context) { return format(context.parsed.y); }
            }
          }
        },
        scales: {
          x: {
            grid: { display: false },
            ticks: {
              maxRotation: 45,
              minRotation: 45,
              font: { size: 10 },
              callback: function(value, index, ticks) {
                if (index % 7 === 0 || index === ticks.length - 1) {
                  return this.getLabelForValue(value);
                }
                return '';
              }
            }
          },
          y: {
            beginAtZero: false,
            grid: { color: 'rgba(0, 0, 0, 0.05)' },
            ticks: {
              font: { size: 10 },
              callback: function(value) { return formatShort(value); }
            }
          }
        }
      }
    });
  },
  _createDividendBar(chartData, currency) {
    const format = currencyFormatter(currency);
    const formatShort = currencyFormatter(currency, 0, 0);
    const avg = chartData.avg_monthly_income || 0;

    const datasets = chartData.datasets.map((dataset, index) => ({
      ...dataset,
      backgroundColor: dividendColors[index % dividendColors.length],
      borderWidth: 0,
      stack: 'bars'
    }));

    const avgLineDataset = {
      label: 'Monthly Average',
      data: chartData.labels.map(() => avg),
      type: 'line',
      borderColor: 'rgba(220, 38, 38, 0.85)',
      borderWidth: 2,
      borderDash: [6, 4],
      pointRadius: 0,
      fill: false,
      order: -1,
      yAxisID: 'y'
    };

    this._chart = new Chart(this.el, {
      type: 'bar',
      data: {
        labels: chartData.labels,
        datasets: [...datasets, avgLineDataset]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: { mode: 'index', intersect: false },
        plugins: {
          legend: {
            display: true,
            position: 'bottom',
            labels: {
              boxWidth: 12,
              padding: 10,
              font: { size: 10 },
              filter: function(item) { return item.text !== 'Monthly Average'; }
            }
          },
          tooltip: {
            callbacks: {
              title: function(context) { return context[0].label; },
              label: function(context) {
                if (context.dataset.label === 'Monthly Average') {
                  return 'Avg: ' + format(context.parsed.y);
                }
                return context.dataset.label + ': ' + format(context.parsed.y);
              },
              footer: function(context) {
                const total = context
                  .filter(item => item.dataset.label !== 'Monthly Average')
                  .reduce((sum, item) => sum + item.parsed.y, 0);
                return 'Total: ' + format(total);
              }
            }
          }
        },
        scales: {
          x: {
            stacked: true,
            grid: { display: false },
            ticks: { font: { size: 10 } }
          },
          y: {
            stacked: true,
            beginAtZero: true,
            grid: { color: 'rgba(0, 0, 0, 0.05)' },
            ticks: {
              font: { size: 10 },
              callback: function(value) { return formatShort(value); }
            }
          }
        }
      }
    });
  },
  _createInvestmentAllocation(chartData, currency) {
    const labels = chartData.map(item => item.label);
    const percentages = chartData.map(item => item.percentage);
    const format = currencyFormatter(currency);

    // Set dynamic height based on number of items
    const container = this.el.parentElement;
    const height = Math.min(600, chartData.length * 50);
    container.style.height = height + 'px';

    this._chart = new Chart(this.el, {
      type: 'bar',
      data: {
        labels: labels,
        datasets: [{
          label: 'Allocation %',
          data: percentages,
          backgroundColor: 'rgba(16, 185, 129, 0.8)',
          borderColor: 'rgb(16, 185, 129)',
          borderWidth: 1
        }]
      },
      options: {
        indexAxis: 'y',
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            callbacks: {
              title: function(context) { return context[0].label; },
              label: function(context) {
                const percentage = context.parsed.x;
                const dataIndex = context.dataIndex;
                const value = chartData[dataIndex].value;
                return [
                  percentage.toFixed(2) + '% of portfolio',
                  'Value: ' + format(value)
                ];
              }
            }
          }
        },
        scales: {
          x: {
            beginAtZero: true,
            max: 100,
            grid: { color: 'rgba(0, 0, 0, 0.05)' },
            ticks: {
              font: { size: 10 },
              callback: function(value) { return value + '%'; }
            },
            title: {
              display: true,
              text: 'Percentage of Portfolio',
              font: { size: 11, weight: 'bold' },
              color: '#374151'
            }
          },
          y: {
            grid: { display: false },
            ticks: { font: { size: 10 }, autoSkip: false }
          }
        }
      }
    });
  }
};

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  hooks: Hooks,
  longPollFallbackMs: 10000,
  params: {
    _csrf_token: csrfToken,
    timezone_offset: new Date().getTimezoneOffset()
  }
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => { topbar.hide(); updateLocalTimes(); })

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// Convert UTC timestamps to local timezone
function formatLocalTime(utcString) {
  const date = new Date(utcString);

  // Format: "Month Day, Year at HH:MM AM/PM"
  const options = {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
    hour12: true
  };

  return date.toLocaleString('en-US', options).replace(',', ' at');
}

function updateLocalTimes() {
  document.querySelectorAll('.local-time[data-utc-time]').forEach(element => {
    const utcTime = element.getAttribute('data-utc-time');
    if (utcTime) {
      element.textContent = formatLocalTime(utcTime);
    }
  });
}

// Update times on page load
document.addEventListener('DOMContentLoaded', updateLocalTimes);

// Update times after LiveView patches the DOM
window.addEventListener("phx:update", updateLocalTimes);
