# The numbers behind the dashboard for one company, in one currency at a time,
# since totals in different currencies can't be added together.
class Dashboard
  PERIODS = %w[ all year last_year quarter month ].freeze
  Summary = Data.define(:count, :total)
  ClientRevenue = Data.define(:client_id, :client_name, :amount)

  attr_reader :period, :currency, :currencies

  def initialize(company, period: nil, currency: nil)
    @currencies = company.invoices.distinct.order(:currency).pluck(:currency)
    @currency = currency.presence_in(@currencies) || default_currency_for(company)
    @invoices = company.invoices.where(currency: @currency)
    @period = period.presence_in(PERIODS) || "all"
  end

  # Revenue counts paid invoices by when they were paid, not when they were issued.
  def revenue
    summarize(paid_in_period)
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

  # Revenue over the period, oldest first, including empty days or months: { Date => amount }.
  # "This month" is broken down by day; every other period by month.
  def revenue_over_time
    range = chart_range or return {}
    group = chart_by_day? ? :paid_on : Arel.sql("DATE_TRUNC('month', invoices.paid_on)::date")
    sums = @invoices.paid.where(paid_on: range).group(group).sum_of_totals
    buckets = chart_by_day? ? range.to_a : range.select { it.day == 1 }

    buckets.index_with { sums.fetch(it, 0) }
  end

  def chart_by_day?
    period == "month"
  end

  # The highest-paying clients in the period.
  def top_clients(limit: 8)
    paid_in_period.joins(:client).group("clients.id", "clients.name").sum_of_totals
      .map { |(client_id, client_name), amount| ClientRevenue.new(client_id:, client_name:, amount:) }
      .max_by(limit, &:amount)
  end

  def recent_payments(limit: 5)
    @invoices.paid.includes(:client, :items).order(paid_on: :desc, id: :desc).limit(limit)
  end

  private
    def default_currency_for(company)
      @currencies.include?(company.default_currency) || @currencies.empty? ? company.default_currency : @currencies.first
    end

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

    # Like period_range, but never past today, and all time starts at the first payment.
    def chart_range
      today = Date.current

      case period
      when "all"
        first_payment = @invoices.paid.minimum(:paid_on)
        first_payment.beginning_of_month..today if first_payment
      when "last_year" then today.prev_year.all_year
      else period_range.begin..today
      end
    end

    def summarize(invoices)
      Summary.new(count: invoices.count, total: invoices.sum_of_totals)
    end
end
