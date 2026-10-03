module DashboardHelper
  PERIOD_LABELS = {
    "all" => "All time",
    "year" => "This year",
    "last_year" => "Last year",
    "quarter" => "This quarter",
    "month" => "This month"
  }.freeze

  def dashboard_period_label(period)
    PERIOD_LABELS.fetch(period)
  end

  # A filter link that keeps the other filter's current choice; the defaults are left out of the URL.
  def dashboard_filter_link(dashboard, label, period: dashboard.period, currency: dashboard.currency)
    current = period == dashboard.period && currency == dashboard.currency
    params = { period: (period unless period == "all"), currency: (currency if dashboard.currencies.many?) }

    link_to label, root_path(params), aria: { current: ("true" if current) },
      class: [ "rounded-md px-3 py-1.5", current ? "bg-brand-600 text-white" : "text-gray-600 hover:bg-gray-100 hover:text-gray-900" ]
  end
end
