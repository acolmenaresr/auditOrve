class AuditDashboardWarmCacheJob < ApplicationJob
  queue_as :default

  def perform(
    periods: [ "last_7_days" ],
    limits: [ 10 ]
  )
    periods.each do |period|
      next if period.to_s == "custom"
      next unless Audit::DateRange::FILTERS.include?(period.to_s)

      range = Audit::DateRange.new(
        filter: period
      )

      limits.each do |limit|
        Audit::DashboardQuery.new(
          from: range.from,
          to: range.to,
          limit: limit
        ).refresh!
      end
    end
  end
end
