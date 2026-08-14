module Audit
  class DashboardQuery
    DEFAULT_LIMIT = 10
    ALLOWED_LIMITS = [ 10, 15, 20 ].freeze

    CACHE_VERSION = "v3"
    CACHE_EXPIRATION = 2.hours

    attr_reader :from, :to, :limit

    def initialize(from:, to:, limit: DEFAULT_LIMIT)
      @from = from
      @to = to
      @limit = normalize_limit(limit)
    end

    def call
      Rails.cache.fetch(
        cache_key,
        expires_in: CACHE_EXPIRATION,
        race_condition_ttl: 2.minutes
      ) do
        execute_dashboard_query
      end
    end

    def refresh!
      result = execute_dashboard_query

      Rails.cache.write(
        cache_key,
        result,
        expires_in: CACHE_EXPIRATION
      )

      result
    end

    private

    def execute_dashboard_query
      sql = AuditMovement.send(
        :sanitize_sql_array,
        [
          <<~SQL,
            WITH base AS (
              SELECT
                NULLIF(
                  LOWER(BTRIM(user_name)),
                  ''
                ) AS user_key,

                NULLIF(
                  BTRIM(user_name),
                  ''
                ) AS user_label,

                COALESCE(
                  NULLIF(BTRIM(source_action), ''),
                  'Sin acción'
                ) AS action_label,

                NULLIF(
                  LOWER(BTRIM(application)),
                  ''
                ) AS application_key,

                NULLIF(
                  BTRIM(application),
                  ''
                ) AS application_label,

                NULLIF(
                  BTRIM(resource_key),
                  ''
                ) AS resource_key,

                (
                  LOWER(
                    BTRIM(
                      COALESCE(user_type, '')
                    )
                  )
                  IN ('anonimo', 'anónimo')
                ) AS is_anonymous

              FROM public.mv_audit_movements

              WHERE occurred_at >= ?
                AND occurred_at < ?
            ),

            grouped AS (
              SELECT
                user_key,
                MIN(user_label) AS user_label,

                action_label,

                application_key,
                MIN(application_label) AS application_label,

                resource_key,
                is_anonymous,

                COUNT(*)::bigint AS events,

                GROUPING(user_key) AS g_user,
                GROUPING(action_label) AS g_action,
                GROUPING(application_key) AS g_application,
                GROUPING(resource_key) AS g_resource,
                GROUPING(is_anonymous) AS g_anonymous

              FROM base

              GROUP BY GROUPING SETS (
                (),
                (user_key),
                (user_key, is_anonymous),
                (action_label),
                (application_key),
                (resource_key),
                (resource_key, is_anonymous)
              )
            ),

            metrics AS (
              SELECT
                COALESCE(
                  MAX(events) FILTER (
                    WHERE
                      g_user = 1
                      AND g_action = 1
                      AND g_application = 1
                      AND g_resource = 1
                      AND g_anonymous = 1
                  ),
                  0
                )::bigint AS total_events,

                COUNT(*) FILTER (
                  WHERE
                    g_user = 0
                    AND g_action = 1
                    AND g_application = 1
                    AND g_resource = 1
                    AND g_anonymous = 1
                    AND user_key IS NOT NULL
                )::bigint AS total_users,

                COUNT(*) FILTER (
                  WHERE
                    g_user = 0
                    AND g_action = 1
                    AND g_application = 1
                    AND g_resource = 1
                    AND g_anonymous = 0
                    AND is_anonymous = true
                    AND user_key IS NOT NULL
                )::bigint AS anonymous_users,

                COUNT(*) FILTER (
                  WHERE
                    g_user = 1
                    AND g_action = 1
                    AND g_application = 1
                    AND g_resource = 0
                    AND g_anonymous = 1
                    AND resource_key IS NOT NULL
                )::bigint AS total_files,

                COUNT(*) FILTER (
                  WHERE
                    g_user = 1
                    AND g_action = 1
                    AND g_application = 0
                    AND g_resource = 1
                    AND g_anonymous = 1
                    AND application_key IS NOT NULL
                )::bigint AS total_applications,

                COUNT(*) FILTER (
                  WHERE
                    g_user = 1
                    AND g_action = 1
                    AND g_application = 1
                    AND g_resource = 0
                    AND g_anonymous = 0
                    AND is_anonymous = true
                    AND resource_key IS NOT NULL
                )::bigint AS anonymous_files,

                COALESCE(
                  SUM(events) FILTER (
                    WHERE
                      g_user = 0
                      AND g_action = 1
                      AND g_application = 1
                      AND g_resource = 1
                      AND g_anonymous = 0
                      AND is_anonymous = true
                  ),
                  0
                )::bigint AS anonymous_events

              FROM grouped
            ),

            top_users AS (
              SELECT
                COALESCE(
                  user_label,
                  'Sin usuario'
                ) AS label,
                events

              FROM grouped

              WHERE
                g_user = 0
                AND g_action = 1
                AND g_application = 1
                AND g_resource = 1
                AND g_anonymous = 1

              ORDER BY
                events DESC,
                label ASC

              LIMIT ?
            ),

            top_actions AS (
              SELECT
                action_label AS label,
                events

              FROM grouped

              WHERE
                g_user = 1
                AND g_action = 0
                AND g_application = 1
                AND g_resource = 1
                AND g_anonymous = 1

              ORDER BY
                events DESC,
                label ASC

              LIMIT ?
            ),

            top_applications AS (
              SELECT
                COALESCE(
                  application_label,
                  'Sin aplicación'
                ) AS label,
                events

              FROM grouped

              WHERE
                g_user = 1
                AND g_action = 1
                AND g_application = 0
                AND g_resource = 1
                AND g_anonymous = 1

              ORDER BY
                events DESC,
                label ASC

              LIMIT ?
            )

            SELECT
              jsonb_build_object(
                'metrics',
                jsonb_build_object(
                  'total_users',
                  metrics.total_users,

                  'anonymous_users',
                  metrics.anonymous_users,

                  'total_events',
                  metrics.total_events,

                  'total_files',
                  metrics.total_files,

                  'total_applications',
                  metrics.total_applications,

                  'anonymous_files',
                  metrics.anonymous_files,

                  'anonymous_events',
                  metrics.anonymous_events
                ),

                'top_users',
                COALESCE(
                  (
                    SELECT jsonb_agg(
                      jsonb_build_object(
                        'label', label,
                        'events', events
                      )
                      ORDER BY events DESC, label ASC
                    )
                    FROM top_users
                  ),
                  '[]'::jsonb
                ),

                'top_actions',
                COALESCE(
                  (
                    SELECT jsonb_agg(
                      jsonb_build_object(
                        'label', label,
                        'events', events
                      )
                      ORDER BY events DESC, label ASC
                    )
                    FROM top_actions
                  ),
                  '[]'::jsonb
                ),

                'top_applications',
                COALESCE(
                  (
                    SELECT jsonb_agg(
                      jsonb_build_object(
                        'label', label,
                        'events', events
                      )
                      ORDER BY events DESC, label ASC
                    )
                    FROM top_applications
                  ),
                  '[]'::jsonb
                )
              ) AS payload

            FROM metrics;
          SQL
          from.beginning_of_day,
          to.beginning_of_day,
          limit,
          limit,
          limit
        ]
      )

      raw_payload =
        AuditMovement.connection.select_value(sql)

      parse_payload(raw_payload)
    end

    def parse_payload(raw_payload)
      payload =
        if raw_payload.is_a?(String)
          JSON.parse(
            raw_payload,
            symbolize_names: true
          )
        else
          raw_payload.deep_symbolize_keys
        end

      {
        metrics: payload[:metrics],
        top_users: payload[:top_users],
        top_actions: payload[:top_actions],
        top_applications: payload[:top_applications]
      }
    end

    def cache_key
      [
        "audit-dashboard",
        CACHE_VERSION,
        from.to_date.iso8601,
        to.to_date.iso8601,
        limit
      ].join(":")
    end

    def normalize_limit(value)
      parsed = Integer(value, exception: false)

      ALLOWED_LIMITS.include?(parsed) ? parsed : DEFAULT_LIMIT
    end
  end
end
