module DashboardHelper
  PERIOD_LABELS = {
    "all" => "All time",
    "year" => "This year",
    "last_year" => "Last year",
    "quarter" => "This quarter",
    "month" => "This month"
  }.freeze

  # Colors for ranked clients, as the hex value for the chart and the matching class for the legend dot.
  # The classes are written out in full so Tailwind finds them.
  CLIENT_COLORS = [
    [ "#9c42e5", "bg-[#9c42e5]" ], [ "#06b6d4", "bg-[#06b6d4]" ], [ "#10b981", "bg-[#10b981]" ], [ "#f59e0b", "bg-[#f59e0b]" ],
    [ "#ec4899", "bg-[#ec4899]" ], [ "#58148f", "bg-[#58148f]" ], [ "#0ea5e9", "bg-[#0ea5e9]" ], [ "#ef4444", "bg-[#ef4444]" ]
  ].freeze

  def due_badge(invoice)
    days = (invoice.due_date - Date.current).to_i

    if days.negative?
      tag.span "#{pluralize(-days, "day")} overdue", class: "rounded-md bg-red-50 px-2 py-1 text-xs font-medium text-red-700"
    else
      label = days.zero? ? "Due today" : "Due in #{pluralize(days, "day")}"
      tag.span label, class: "rounded-md bg-amber-50 px-2 py-1 text-xs font-medium text-amber-700"
    end
  end

  def dashboard_period_label(period)
    PERIOD_LABELS.fetch(period)
  end

  def client_color(index)
    CLIENT_COLORS[index % CLIENT_COLORS.size]
  end

  # A filter link that keeps the other filter's current choice; the defaults are left out of the URL.
  def dashboard_filter_link(dashboard, label, period: dashboard.period, currency: dashboard.currency)
    current = period == dashboard.period && currency == dashboard.currency
    params = { period: (period unless period == "all"), currency: (currency if dashboard.currencies.many?) }

    filter_link label, root_path(params), current:
  end
end
