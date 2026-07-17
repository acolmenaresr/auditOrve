module Audit
  class DashboardQuery
    DEFAULT_LIMIT = 10
    ALLOWED_LIMITS = [ 10, 15, 20 ].freeze

    attr_reader :from, :to, :limit

    def initialize(from:, to:, limit: DEFAULT_LIMIT)
      @from = from
      @to = to
      @limit = normalize_limit(limit)
    end

    def call
      {
        metrics: metrics,
        top_users: top_users,
        top_actions: top_actions,
        top_applications: top_applications
      }
    end

    private

    def scope
      @scope ||= AuditLog.where(
        '"fechaEv" >= ? AND "fechaEv" < ?',
        from,
        to
      )
    end

    def metrics
      values = scope.pick(
        Arel.sql(
          'COUNT(DISTINCT NULLIF(LOWER(TRIM("usuario")), \'\'))'
        ),
        Arel.sql(
          <<~SQL.squish
            COUNT(
              DISTINCT NULLIF(LOWER(TRIM("usuario")), '')
            ) FILTER (
              WHERE LOWER(TRIM(COALESCE("tipoUsuario"::text, '')))
              IN ('anonimo', 'anónimo')
            )
          SQL
        ),
        Arel.sql("COUNT(*)"),
        Arel.sql(
          <<~SQL.squish
            COUNT(
              DISTINCT COALESCE(
                NULLIF(TRIM("ruta"), ''),
                NULLIF(TRIM("url"), ''),
                NULLIF(TRIM("archivo"), '')
              )
            )
          SQL
        ),
        Arel.sql(
          'COUNT(DISTINCT NULLIF(LOWER(TRIM("aplicacion")), \'\'))'
        ),
        Arel.sql(
          <<~SQL.squish
            COUNT(
              DISTINCT COALESCE(
                NULLIF(TRIM("ruta"), ''),
                NULLIF(TRIM("url"), ''),
                NULLIF(TRIM("archivo"), '')
              )
            ) FILTER (
              WHERE LOWER(TRIM(COALESCE("tipoUsuario"::text, '')))
              IN ('anonimo', 'anónimo')
            )
          SQL
        ),
        Arel.sql(
          <<~SQL.squish
            COUNT(*) FILTER (
              WHERE LOWER(TRIM(COALESCE("tipoUsuario"::text, '')))
              IN ('anonimo', 'anónimo')
            )
          SQL
        )
      )

      {
        total_users: values[0].to_i,
        anonymous_users: values[1].to_i,
        total_events: values[2].to_i,
        total_files: values[3].to_i,
        total_applications: values[4].to_i,
        anonymous_files: values[5].to_i,
        anonymous_events: values[6].to_i
      }
    end

    def top_users
      ranked_rows(
        %{COALESCE(NULLIF(TRIM("usuario"), ''), 'Sin usuario')}
      )
    end

    def top_actions
      ranked_rows(
        %{COALESCE(NULLIF(TRIM("accion"), ''), 'Sin acción')}
      )
    end

    def top_applications
      ranked_rows(
        %{COALESCE(NULLIF(TRIM("aplicacion"), ''), 'Sin aplicación')}
      )
    end

    def ranked_rows(label_expression)
      scope
        .group(Arel.sql(label_expression))
        .order(Arel.sql("COUNT(*) DESC"))
        .limit(limit)
        .pluck(
          Arel.sql(label_expression),
          Arel.sql("COUNT(*)")
        )
        .map do |label, events|
          {
            label: label,
            events: events.to_i
          }
        end
    end

    def normalize_limit(value)
      parsed = Integer(value, exception: false)

      ALLOWED_LIMITS.include?(parsed) ? parsed : DEFAULT_LIMIT
    end
  end
end
