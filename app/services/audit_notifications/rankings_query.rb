module AuditNotifications
  class RankingsQuery
    DEFAULT_LIMIT = 10
    ALLOWED_LIMITS = [ 10, 15, 20 ].freeze

    PERIOD_SQL =
      'COALESCE("dateZ", "createdAt") >= ? AND COALESCE("dateZ", "createdAt") < ?'.freeze

    def initialize(from:, to:, limit: DEFAULT_LIMIT)
      @from = from
      @to = to
      @limit = normalize_limit(limit)
    end

    def call
      {
        top_alert_users: top_alert_users,
        top_alert_types: top_alert_types
      }
    end

    private

    def period_scope
      AuditNotification.where(
        PERIOD_SQL,
        @from.beginning_of_day,
        @to.beginning_of_day
      )
    end

    def top_alert_users
      rows = period_scope
        .where("BTRIM(COALESCE(\"usuario\", '')) <> ''")
        .group(Arel.sql('LOWER(BTRIM("usuario"))'))
        .order(Arel.sql("COUNT(*) DESC, MIN(\"usuario\") ASC"))
        .limit(@limit)
        .pluck(
          Arel.sql('MIN("usuario")'),
          Arel.sql("COUNT(*)::bigint")
        )

      rows.map do |label, events|
        { label: label.to_s, events: events.to_i }
      end
    end

    def top_alert_types
      rows = period_scope
        .where("BTRIM(COALESCE(\"motivo\", '')) <> ''")
        .group(Arel.sql('BTRIM("motivo")'))
        .order(Arel.sql("COUNT(*) DESC, BTRIM(\"motivo\") ASC"))
        .limit(@limit)
        .pluck(
          Arel.sql('BTRIM("motivo")'),
          Arel.sql("COUNT(*)::bigint")
        )

      rows.map do |label, events|
        { label: label.to_s, events: events.to_i }
      end
    end

    def normalize_limit(value)
      parsed = Integer(value, exception: false)
      ALLOWED_LIMITS.include?(parsed) ? parsed : DEFAULT_LIMIT
    end
  end
end
