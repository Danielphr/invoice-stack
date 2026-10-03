# The numbers behind the dashboard for one company. Amounts are kept per currency,
# since totals in different currencies can't be added together.
class Dashboard
  PERIODS = %w[ all year last_year quarter month ].freeze
  Summary = Data.define(:count, :totals)
  ClientRevenue = Data.define(:client_id, :client_name, :currency, :amount)

  attr_reader :period

  def initialize(company, period: nil)
    @invoices = company.invoices
    @period = period.presence_in(PERIODS) || "all"
  end

  # Revenue counts paid invoices by when they were paid, not when they were issued.
  def revenue
    paid_in_period.total_by_currency
  end

  def outstanding
    summarize(@invoices.sent)
  end

  def overdue
    summarize(@invoices.overdue)
  end

  def drafts_count
    @invoices.draft.count
  end

  # { Date (first of the month) => { "USD" => amount } } for the last few months, oldest first, including empty months.
  def revenue_by_month(months: 12)
    first_month = Date.current.beginning_of_month << (months - 1)
    sums = @invoices.paid.where(paid_on: first_month..)
      .group(Arel.sql("DATE_TRUNC('month', invoices.paid_on)::date"), :currency).sum_of_totals

    Array.new(months) { first_month >> it }.index_with do |month|
      sums.filter_map { |(sum_month, currency), amount| [ currency, amount ] if sum_month == month }.sort.to_h
    end
  end

  # The highest-paying clients in each currency.
  def top_clients(limit: 5)
    paid_in_period.joins(:client).group("clients.id", "clients.name", :currency).sum_of_totals
      .map { |(client_id, client_name, currency), amount| ClientRevenue.new(client_id:, client_name:, currency:, amount:) }
      .group_by(&:currency).sort.flat_map { |_currency, revenues| revenues.max_by(limit, &:amount) }
  end

  def recent_payments(limit: 5)
    @invoices.paid.includes(:client, :items).order(paid_on: :desc, id: :desc).limit(limit)
  end

  private
    def paid_in_period
      range = period_range
      range ? @invoices.paid.where(paid_on: range) : @invoices.paid
    end

    def period_range
      today = Date.current

      case period
      when "year" then today.all_year
      when "last_year" then today.prev_year.all_year
      when "quarter" then today.all_quarter
      when "month" then today.all_month
      end
    end

    def summarize(invoices)
      Summary.new(count: invoices.count, totals: invoices.total_by_currency)
    end
end
