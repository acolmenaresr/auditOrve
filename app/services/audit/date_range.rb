module Audit
  class DateRange
    DEFAULT_FILTER = "last_7_days"

    FILTERS = %w[
      today
      yesterday
      last_7_days
      last_30_days
      this_week
      last_week
      this_month
      last_month
      this_year
      custom
    ].freeze

    attr_reader :filter, :from, :to

    def initialize(filter:, custom_from: nil, custom_to: nil)
      @filter = normalize_filter(filter)
      @custom_from = parse_date(custom_from)
      @custom_to = parse_date(custom_to)

      @from, @to = calculate_range
    end

    private

    def normalize_filter(value)
      value = value.to_s

      FILTERS.include?(value) ? value : DEFAULT_FILTER
    end

    def parse_date(value)
      return if value.blank?

      Date.iso8601(value.to_s)
    rescue Date::Error
      nil
    end

    def calculate_range
      today = Date.current

      case filter
      when "today"
        [today, today + 1.day]
      when "yesterday"
        [today - 1.day, today]
      when "last_7_days"
        [today - 6.days, today + 1.day]
      when "last_30_days"
        [today - 29.days, today + 1.day]
      when "this_week"
        start_date = today.beginning_of_week(:monday)
        [start_date, start_date + 1.week]
      when "last_week"
        end_date = today.beginning_of_week(:monday)
        [end_date - 1.week, end_date]
      when "this_month"
        start_date = today.beginning_of_month
        [start_date, start_date.next_month]
      when "last_month"
        end_date = today.beginning_of_month
        [end_date.prev_month, end_date]
      when "this_year"
        start_date = today.beginning_of_year
        [start_date, start_date.next_year]
      when "custom"
        custom_range(today)
      else
        [today - 6.days, today + 1.day]
      end
    end

    def custom_range(today)
      start_date = @custom_from || today - 6.days
      end_date = @custom_to || today

      end_date = start_date if end_date < start_date

      [start_date, end_date + 1.day]
    end
  end
end