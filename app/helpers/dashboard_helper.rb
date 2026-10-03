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
end
