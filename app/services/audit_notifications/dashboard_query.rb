module AuditNotifications
  class DashboardQuery
    DEFAULT_PAGE = 1
    DEFAULT_PAGE_SIZE = 10
    MAX_PAGE_SIZE = 100
    ASSIGNMENT_FILTERS = %w[mias sin_asignar].freeze

    PERIOD_SQL =
      'COALESCE("dateZ", "createdAt") >= ? AND COALESCE("dateZ", "createdAt") < ?'.freeze

    ASSIGNED_EMAIL_SQL =
      "LOWER(BTRIM(COALESCE(\"asignadoA\", ''))) = ?".freeze

    UNASSIGNED_SQL =
      "BTRIM(COALESCE(\"asignadoA\", '')) = ''".freeze

    QUEUE_VISIBILITY_SQL =
      "BTRIM(COALESCE(\"asignadoA\", '')) = '' OR " \
      "LOWER(BTRIM(COALESCE(\"asignadoA\", ''))) = ?".freeze

    DEFAULT_ORDER_SQL =
      '"nivel" DESC NULLS LAST, ' \
      'COALESCE("dateZ", "createdAt") DESC NULLS LAST, ' \
      "id DESC".freeze

    QUEUE_ORDER_SQL = <<~SQL.squish.freeze
      CASE WHEN LOWER(BTRIM(COALESCE("asignadoA", ''))) = ? THEN 0 ELSE 1 END,
      CASE
        WHEN LOWER(BTRIM(COALESCE("asignadoA", ''))) = ?
        THEN COALESCE("updatedAt", "createdAt")
        ELSE COALESCE("dateZ", "createdAt")
      END ASC NULLS LAST,
      id ASC
    SQL

    attr_reader :from,
                :to,
                :status,
                :severity,
                :assignment,
                :page,
                :page_size

    def initialize(
      from:,
      to:,
      status: nil,
      severity: nil,
      assignment: nil,
      viewer: nil,
      restrict_to_queue: false,
      user_principal_name: nil,
      page: DEFAULT_PAGE,
      page_size: DEFAULT_PAGE_SIZE
    )
      @from = from
      @to = to
      @status = normalize_status(status)
      @severity = normalize_severity(severity)
      @assignment = normalize_assignment(assignment)
      @viewer = viewer
      @restrict_to_queue = restrict_to_queue
      @user_principal_name =
        normalize_upn(user_principal_name)
      @page = normalize_page(page)
      @page_size = normalize_page_size(page_size)
    end

    def metrics
      @metrics ||= load_metrics
    end

    def records
      @records ||= filtered_scope
        .order(Arel.sql(order_sql))
        .limit(page_size)
        .offset(offset)
    end

    def total_count
      @total_count ||= filtered_scope.count
    end

    def total_pages
      return 1 if total_count.zero?

      (total_count.to_f / page_size).ceil
    end

    private

    def period_scope
      scope = AuditNotification.where(
        PERIOD_SQL,
        from.beginning_of_day,
        to.beginning_of_day
      )

      if @user_principal_name.present?
        scope = scope.where(
          'LOWER(BTRIM("usuario")) = ?',
          @user_principal_name
        )
      end

      apply_queue_visibility(scope)
    end

    def filtered_scope
      scope = period_scope
      scope = apply_assignment_filter(scope)
      scope = apply_status_filter(scope)
      scope = scope.where(severidad: severity) if severity.present?
      scope
    end

    def apply_queue_visibility(scope)
      return scope unless @restrict_to_queue
      return scope if viewer_email.blank?

      scope.where(QUEUE_VISIBILITY_SQL, viewer_email)
    end

    def apply_assignment_filter(scope)
      return scope if assignment.blank?

      if assignment == "sin_asignar"
        return scope.where(UNASSIGNED_SQL)
      end

      email = assignment_email
      return scope.none if email.blank?

      if @restrict_to_queue && email != viewer_email
        return scope.none
      end

      scope.where(ASSIGNED_EMAIL_SQL, email)
    end

    def assignment_email
      return viewer_email if assignment == "mias"

      assignee = AuditUser.find_by(id: assignment)
      assignee&.usuario.to_s.strip.downcase.presence
    end

    def apply_status_filter(scope)
      return scope if status.blank?

      if status == "en_trabajo"
        return scope.where(
          estado: AuditNotification::IN_PROGRESS_STATUSES
        )
      end

      scope.where(estado: status)
    end

    def order_sql
      if queue_sort?
        return queue_order_sql
      end

      DEFAULT_ORDER_SQL
    end

    def queue_sort?
      @restrict_to_queue || assignment.present?
    end

    def queue_order_sql
      ActiveRecord::Base.sanitize_sql_array(
        [
          QUEUE_ORDER_SQL,
          viewer_email,
          viewer_email
        ]
      )
    end

    def viewer_email
      @viewer&.usuario.to_s.strip.downcase
    end

    def load_metrics
      row = period_scope.pick(
        Arel.sql("COUNT(*)::bigint"),
        Arel.sql("COUNT(*) FILTER (WHERE severidad = 'critica')::bigint"),
        Arel.sql("COUNT(*) FILTER (WHERE severidad = 'alta')::bigint"),
        Arel.sql("COUNT(*) FILTER (WHERE severidad = 'media')::bigint"),
        Arel.sql("COUNT(*) FILTER (WHERE severidad = 'baja')::bigint"),
        Arel.sql("COUNT(*) FILTER (WHERE estado = 'pendiente')::bigint"),
        Arel.sql(
          "COUNT(*) FILTER (WHERE estado IN ('asignada', 'en_revision'))::bigint"
        ),
        Arel.sql("COUNT(*) FILTER (WHERE estado = 'resuelta')::bigint")
      ) || Array.new(8, 0)

      {
        total: row[0].to_i,
        critica: row[1].to_i,
        alta: row[2].to_i,
        media: row[3].to_i,
        baja: row[4].to_i,
        pendiente: row[5].to_i,
        en_trabajo: row[6].to_i,
        atendida: row[7].to_i
      }
    end

    def offset
      (page - 1) * page_size
    end

    def normalize_upn(value)
      value.to_s.strip.downcase.presence
    end

    def normalize_assignment(value)
      normalized = value.to_s.strip
      return if normalized.blank?
      return normalized if ASSIGNMENT_FILTERS.include?(normalized)
      return normalized if normalized.match?(/\A\d+\z/)

      nil
    end

    def normalize_status(value)
      normalized = value.to_s.strip
      return if normalized.blank?

      return "en_trabajo" if normalized == "en_trabajo"

      AuditNotification::STATUSES.include?(normalized) ?
        normalized :
        nil
    end

    def normalize_severity(value)
      normalized = value.to_s.strip
      return if normalized.blank?

      AuditNotification::SEVERITIES.include?(normalized) ?
        normalized :
        nil
    end

    def normalize_page(value)
      parsed = value.to_i
      parsed.positive? ? parsed : DEFAULT_PAGE
    end

    def normalize_page_size(value)
      parsed = value.to_i
      parsed = DEFAULT_PAGE_SIZE unless parsed.positive?

      [ parsed, MAX_PAGE_SIZE ].min
    end
  end
end
