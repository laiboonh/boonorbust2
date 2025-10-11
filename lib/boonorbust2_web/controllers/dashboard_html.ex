defmodule Boonorbust2Web.DashboardHTML do
  use Boonorbust2Web, :html

  def index(assigns) do
    ~H"""
    <.tab_content class="min-h-screen bg-gray-50">
      <div class="px-4 py-8">
        <div class="max-w-lg mx-auto">
          <%= if Enum.empty?(@portfolios) do %>
            <div class="bg-white rounded-lg shadow p-8 text-center">
              <p class="text-gray-500 mb-4">No portfolios yet.</p>
              <p class="text-sm text-gray-400">
                Create a portfolio and tag your assets to see your portfolio breakdown here.
              </p>
            </div>
          <% else %>
            <div class="space-y-6">
              <%= for {portfolio, index} <- Enum.with_index(@portfolios) do %>
                <%= if !Enum.empty?(portfolio.chart_data) do %>
                  <div class="bg-white rounded-lg shadow p-6">
                    <div class="mb-4">
                      <h2 class="text-lg font-semibold text-gray-900">{portfolio.name}</h2>
                      <%= if portfolio.description do %>
                        <p class="text-sm text-gray-600 mt-1">{portfolio.description}</p>
                      <% end %>
                    </div>
                    <div class="relative" style="height: 400px;">
                      <canvas id={"portfolio-chart-#{portfolio.id}"}></canvas>
                    </div>
                    <script>
                      (function() {
                        const ctx = document.getElementById('portfolio-chart-<%= portfolio.id %>');
                        if (ctx && typeof Chart !== 'undefined') {
                          const data = <%= raw Jason.encode!(portfolio.chart_data) %>;
                          const labels = data.map(item => item.label);
                          const values = data.map(item => item.value);

                          // Different color schemes for each portfolio
                          const colorSchemes = [
                            // Distinct Hues (high contrast)
                            ['rgb(59, 130, 246)', 'rgb(239, 68, 68)', 'rgb(16, 185, 129)', 'rgb(249, 115, 22)', 'rgb(147, 51, 234)', 'rgb(6, 182, 212)', 'rgb(236, 72, 153)', 'rgb(251, 191, 36)', 'rgb(99, 102, 241)', 'rgb(20, 184, 166)'],
                            // Warm Sunset
                            ['rgb(239, 68, 68)', 'rgb(249, 115, 22)', 'rgb(251, 191, 36)', 'rgb(245, 158, 11)', 'rgb(252, 211, 77)', 'rgb(234, 88, 12)', 'rgb(220, 38, 38)', 'rgb(248, 113, 113)', 'rgb(251, 146, 60)', 'rgb(252, 165, 165)'],
                            // Ocean Greens
                            ['rgb(16, 185, 129)', 'rgb(5, 150, 105)', 'rgb(6, 182, 212)', 'rgb(20, 184, 166)', 'rgb(14, 165, 233)', 'rgb(34, 211, 238)', 'rgb(52, 211, 153)', 'rgb(45, 212, 191)', 'rgb(125, 211, 252)', 'rgb(103, 232, 249)'],
                            // Rose & Pink
                            ['rgb(236, 72, 153)', 'rgb(219, 39, 119)', 'rgb(244, 114, 182)', 'rgb(251, 113, 133)', 'rgb(190, 24, 93)', 'rgb(249, 168, 212)', 'rgb(251, 207, 232)', 'rgb(225, 29, 72)', 'rgb(190, 18, 60)', 'rgb(244, 63, 94)'],
                            // Earth Tones
                            ['rgb(217, 119, 6)', 'rgb(146, 64, 14)', 'rgb(180, 83, 9)', 'rgb(120, 53, 15)', 'rgb(202, 138, 4)', 'rgb(161, 98, 7)', 'rgb(245, 158, 11)', 'rgb(251, 191, 36)', 'rgb(252, 211, 77)', 'rgb(253, 224, 71)'],
                            // Cool Grays & Blues
                            ['rgb(71, 85, 105)', 'rgb(100, 116, 139)', 'rgb(148, 163, 184)', 'rgb(51, 65, 85)', 'rgb(30, 41, 59)', 'rgb(15, 23, 42)', 'rgb(203, 213, 225)', 'rgb(226, 232, 240)', 'rgb(241, 245, 249)', 'rgb(248, 250, 252)']
                          ];

                          const portfolioIndex = <%= index %>;
                          const colors = colorSchemes[portfolioIndex % colorSchemes.length];

                          new Chart(ctx, {
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
                              layout: {
                                padding: {
                                  top: 20,
                                  bottom: 20,
                                  left: 20,
                                  right: 20
                                }
                              },
                              plugins: {
                                legend: {
                                  display: false
                                },
                                tooltip: {
                                  displayColors: false,
                                  callbacks: {
                                    title: function() {
                                      return '';
                                    },
                                    label: function(context) {
                                      const value = context.parsed;
                                      const currency = '<%= @user_currency %>';
                                      const formatted = new Intl.NumberFormat('en-US', {
                                        style: 'currency',
                                        currency: currency,
                                        minimumFractionDigits: 2,
                                        maximumFractionDigits: 2
                                      }).format(value);
                                      return formatted;
                                    }
                                  }
                                },
                                datalabels: {
                                  color: '#1f2937',
                                  font: {
                                    weight: 'bold',
                                    size: 10
                                  },
                                  anchor: 'end',
                                  align: 'start',
                                  offset: 8,
                                  clamp: false,
                                  padding: {
                                    top: 2,
                                    bottom: 2,
                                    left: 4,
                                    right: 4
                                  },
                                  formatter: function(value, context) {
                                    const total = context.dataset.data.reduce((a, b) => a + b, 0);
                                    const percentage = ((value / total) * 100).toFixed(1);
                                    const label = context.chart.data.labels[context.dataIndex];
                                    return label + '\n' + percentage + '%';
                                  }
                                }
                              }
                            },
                            plugins: [ChartDataLabels]
                          });
                        }
                      })();
                    </script>
                  </div>
                <% end %>
              <% end %>
            </div>
          <% end %>
          
    <!-- Portfolio Value Line Chart -->
          <%= if !Enum.empty?(@portfolio_snapshots) do %>
            <div class="bg-white rounded-lg shadow p-6 mt-6">
              <div class="mb-4">
                <h2 class="text-lg font-semibold text-gray-900">Portfolio Value Over Time</h2>
                <p class="text-sm text-gray-600 mt-1">Last 90 days</p>
              </div>
              <div class="relative" style="height: 300px;">
                <canvas id="portfolio-value-chart"></canvas>
              </div>
              <script>
                (function() {
                  const ctx = document.getElementById('portfolio-value-chart');
                  if (ctx && typeof Chart !== 'undefined') {
                    const snapshots = <%= raw Jason.encode!(@portfolio_snapshots) %>;
                    const labels = snapshots.map(s => s.snapshot_date);
                    const values = snapshots.map(s => parseFloat(s.total_value.amount));

                    new Chart(ctx, {
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
                        interaction: {
                          mode: 'index',
                          intersect: false
                        },
                        plugins: {
                          legend: {
                            display: false
                          },
                          tooltip: {
                            displayColors: false,
                            callbacks: {
                              title: function(context) {
                                return context[0].label;
                              },
                              label: function(context) {
                                const value = context.parsed.y;
                                const currency = '<%= @user_currency %>';
                                return new Intl.NumberFormat('en-US', {
                                  style: 'currency',
                                  currency: currency,
                                  minimumFractionDigits: 2,
                                  maximumFractionDigits: 2
                                }).format(value);
                              }
                            }
                          }
                        },
                        scales: {
                          x: {
                            grid: {
                              display: false
                            },
                            ticks: {
                              maxRotation: 45,
                              minRotation: 45,
                              font: {
                                size: 10
                              },
                              callback: function(value, index, ticks) {
                                // Show every 7th label to avoid crowding
                                if (index % 7 === 0 || index === ticks.length - 1) {
                                  return this.getLabelForValue(value);
                                }
                                return '';
                              }
                            }
                          },
                          y: {
                            beginAtZero: false,
                            grid: {
                              color: 'rgba(0, 0, 0, 0.05)'
                            },
                            ticks: {
                              font: {
                                size: 10
                              },
                              callback: function(value) {
                                const currency = '<%= @user_currency %>';
                                return new Intl.NumberFormat('en-US', {
                                  style: 'currency',
                                  currency: currency,
                                  minimumFractionDigits: 0,
                                  maximumFractionDigits: 0
                                }).format(value);
                              }
                            }
                          }
                        }
                      }
                    });
                  }
                })();
              </script>
            </div>
          <% end %>
        </div>

        <.tab_bar current_tab="dashboard">
          <:tab navigate={~p"/dashboard"} name="dashboard" icon="hero-home">
            Dashboard
          </:tab>
          <:tab navigate={~p"/positions"} name="positions" icon="hero-chart-bar">
            Positions
          </:tab>
          <:tab navigate={~p"/assets"} name="assets" icon="hero-squares-2x2">
            Assets
          </:tab>
          <:tab navigate={~p"/portfolio_transactions"} name="transactions" icon="hero-document-text">
            Transactions
          </:tab>
          <:tab navigate={~p"/portfolios"} name="portfolios" icon="hero-folder">
            Portfolios
          </:tab>
        </.tab_bar>
      </div>
    </.tab_content>
    """
  end
end
