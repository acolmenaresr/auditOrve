module AuditNotifications
  class DashboardQuery
    DEFAULT_PAGE = 1
    DEFAULT_PAGE_SIZE = 10
    MAX_PAGE_SIZE = 100
    ASSIGNMENT_FILTERS = %w[mias sin_asignar].freeze

    CLOSED_STATUSES = %w[resuelta descartada].freeze
    OPEN_STATUSES = (
      AuditNotification::STATUSES - CLOSED_STATUSES
    ).freeze

    PERIOD_SQL =
      'COALESCE("dateZ", "createdAt") >= ? AND COALESCE("dateZ", "createdAt") < ?'.freeze

    ASSIGNED_EMAIL_SQL =
      "LOWER(BTRIM(COALESCE(\"asignadoA\", ''))) = ?".freeze

    UNASSIGNED_SQL =
      "BTRIM(COALESCE(\"asignadoA\", '')) = ''".freeze

    QUEUE_VISIBILITY_SQL =
      "BTRIM(COALESCE(\"asignadoA\", '')) = '' OR " \
      "LOWER(BTRIM(COALESCE(\"asignadoA\", ''))) = ?".freeze

    # En activas: asignadas primero, luego sin asignar.
    OPEN_ORDER_SQL = <<~SQL.squish.freeze
      CASE
        WHEN BTRIM(COALESCE("asignadoA", '')) = '' THEN 1
        ELSE 0
      END,
      "nivel" DESC NULLS LAST,
      COALESCE("dateZ", "createdAt") DESC NULLS LAST,
      id DESC
    SQL

    CLOSED_ORDER_SQL = <<~SQL.squish.freeze
      "nivel" DESC NULLS LAST,
      COALESCE("dateZ", "createdAt") DESC NULLS LAST,
      id DESC
    SQL

    # Compat for existing tests that reference DEFAULT_ORDER_SQL.
    DEFAULT_ORDER_SQL = OPEN_ORDER_SQL

    attr_reader :from,
                :to,
                :status,
                :severity,
                :assignment,
                :motive,
                :page,
                :closed_page,
                :page_size

    def initialize(
      from:,
      to:,
      status: nil,
      severity: nil,
      assignment: nil,
      motive: nil,
      viewer: nil,
      restrict_to_queue: false,
      user_principal_name: nil,
      page: DEFAULT_PAGE,
      closed_page: DEFAULT_PAGE,
      page_size: DEFAULT_PAGE_SIZE
    )
      @from = from
      @to = to
      @status = normalize_status(status)
      @severity = normalize_severity(severity)
      @assignment = normalize_assignment(assignment)
      @motive = normalize_motive(motive)
      @viewer = viewer
      @restrict_to_queue = restrict_to_queue
      @user_principal_name =
        normalize_upn(user_principal_name)
      @page = normalize_page(page)
      @closed_page = normalize_page(closed_page)
      @page_size = normalize_page_size(page_size)
    end

    def metrics
      @metrics ||= load_metrics
    end

    def motive_options
      @motive_options ||= begin
        values = period_scope
          .where("BTRIM(COALESCE(\"motivo\", '')) <> ''")
          .group(Arel.sql('BTRIM("motivo")'))
          .order(Arel.sql('BTRIM("motivo") ASC'))
          .limit(300)
          .pluck(Arel.sql('BTRIM("motivo")'))
          .map(&:to_s)

        if motive.present? && values.exclude?(motive)
          values = [ motive ] + values
        end

        values
      end
    end

    def show_open_table?
      return true if status.blank?
      return true if status == "activas"
      return false if status == "finalizadas"
      return false if CLOSED_STATUSES.include?(status)

      true
    end

    def show_closed_table?
      return true if status.blank?
      return true if status == "finalizadas"
      return false if status == "activas"
      return true if CLOSED_STATUSES.include?(status)

      false
    end

    def open_records
      return AuditNotification.none unless show_open_table?

      @open_records ||= open_scope
        .order(Arel.sql(OPEN_ORDER_SQL))
        .limit(page_size)
        .offset(open_offset)
    end

    def closed_records
      return AuditNotification.none unless show_closed_table?

      @closed_records ||= closed_scope
        .order(Arel.sql(CLOSED_ORDER_SQL))
        .limit(page_size)
        .offset(closed_offset)
    end

    def records
      @records ||= Array(open_records) + Array(closed_records)
    end

    def open_total_count
      @open_total_count ||=
        show_open_table? ? open_scope.count : 0
    end

    def closed_total_count
      @closed_total_count ||=
        show_closed_table? ? closed_scope.count : 0
    end

    def total_count
      open_total_count + closed_total_count
    end

    def open_total_pages
      pages_for(open_total_count)
    end

    def closed_total_pages
      pages_for(closed_total_count)
    end

    def total_pages
      pages_for(total_count)
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

    def shared_filters_scope
      scope = apply_assignment_filter(period_scope)
      scope = scope.where(severidad: severity) if severity.present?
      if motive.present?
        scope = scope.where('BTRIM("motivo") = ?', motive)
      end
      scope
    end

    def open_scope
      scope = shared_filters_scope

      case status
      when nil, "activas"
        scope.where(estado: OPEN_STATUSES)
      when "en_trabajo"
        scope.where(estado: AuditNotification::IN_PROGRESS_STATUSES)
      when "pendiente", "asignada", "en_revision"
        scope.where(estado: status)
      else
        scope.none
      end
    end

    def closed_scope
      scope = shared_filters_scope

      case status
      when nil, "finalizadas"
        scope.where(estado: CLOSED_STATUSES)
      when "resuelta", "descartada"
        scope.where(estado: status)
      else
        scope.none
      end
    end

    def filtered_scope
      scope = shared_filters_scope
      apply_status_filter(scope)
    end

    def metrics_base_scope
      apply_assignment_filter(period_scope)
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

      if status == "activas"
        return scope.where(estado: OPEN_STATUSES)
      end

      if status == "finalizadas"
        return scope.where(estado: CLOSED_STATUSES)
      end

      scope.where(estado: status)
    end

    def viewer_email
      @viewer&.usuario.to_s.strip.downcase
    end

    def load_metrics
      status_scope = metrics_base_scope
      if severity.present?
        status_scope = status_scope.where(severidad: severity)
      end

      severity_scope = metrics_base_scope
      severity_scope = apply_status_filter(severity_scope)

      total = filtered_scope.count

      status_row = status_scope.pick(
        Arel.sql("COUNT(*) FILTER (WHERE estado = 'pendiente')::bigint"),
        Arel.sql(
          "COUNT(*) FILTER (WHERE estado IN ('asignada', 'en_revision'))::bigint"
        ),
        Arel.sql(
          "COUNT(*) FILTER (WHERE estado IN ('resuelta', 'descartada'))::bigint"
        ),
        Arel.sql(
          "COUNT(*) FILTER (WHERE BTRIM(COALESCE(\"asignadoA\", '')) = '')::bigint"
        )
      ) || Array.new(4, 0)

      severity_row = severity_scope.pick(
        Arel.sql("COUNT(*) FILTER (WHERE severidad = 'critica')::bigint"),
        Arel.sql("COUNT(*) FILTER (WHERE severidad = 'alta')::bigint"),
        Arel.sql("COUNT(*) FILTER (WHERE severidad = 'media')::bigint"),
        Arel.sql("COUNT(*) FILTER (WHERE severidad = 'baja')::bigint")
      ) || Array.new(4, 0)

      {
        total: total,
        pendiente: status_row[0].to_i,
        en_trabajo: status_row[1].to_i,
        atendida: status_row[2].to_i,
        sin_asignar: status_row[3].to_i,
        critica: severity_row[0].to_i,
        alta: severity_row[1].to_i,
        media: severity_row[2].to_i,
        baja: severity_row[3].to_i,
        severity_total:
          severity_row.sum { |value| value.to_i }
      }
    end

    def open_offset
      (page - 1) * page_size
    end

    def closed_offset
      (closed_page - 1) * page_size
    end

    def pages_for(count)
      return 1 if count.zero?

      (count.to_f / page_size).ceil
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
      return "activas" if normalized == "activas"
      return "finalizadas" if normalized == "finalizadas"

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

    def normalize_motive(value)
      value.to_s.strip.presence
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
