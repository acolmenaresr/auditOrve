module AuditNotifications
  class InboxSummary
    Result = Struct.new(:total, :items, keyword_init: true)
    Item = Struct.new(
      :kind,
      :title,
      :hint,
      :path,
      :category,
      :grouped,
      keyword_init: true
    )

    MAX_ASSIGNED_ITEMS = 80
    MOTIVO_LIMIT = 150

    ORDER_SQL =
      '"nivel" DESC NULLS LAST, ' \
      'COALESCE("dateZ", "createdAt") DESC NULLS LAST, ' \
      "id DESC".freeze

    ASSIGNED_EMAIL_SQL =
      "LOWER(BTRIM(COALESCE(\"asignadoA\", ''))) = ?".freeze

    UNASSIGNED_SQL =
      "BTRIM(COALESCE(\"asignadoA\", '')) = ''".freeze

    QUEUE_VISIBILITY_SQL =
      "BTRIM(COALESCE(\"asignadoA\", '')) = '' OR " \
      "LOWER(BTRIM(COALESCE(\"asignadoA\", ''))) = ?".freeze

    SEVERITY_LABELS = {
      "critica" => "Crítica",
      "alta" => "Alta",
      "media" => "Media",
      "baja" => "Baja"
    }.freeze

    def initialize(viewer:, restrict_to_queue: false)
      @viewer = viewer
      @restrict_to_queue = restrict_to_queue
    end

    def call
      email = viewer_email

      return empty_result if email.blank?

      assigned_scope = visible_scope(email)
        .where(ASSIGNED_EMAIL_SQL, email)
        .where(estado: AuditNotification::IN_PROGRESS_STATUSES)

      new_scope = visible_scope(email)
        .where(UNASSIGNED_SQL)
        .where(estado: "pendiente")

      assigned_records = assigned_scope
        .order(Arel.sql(ORDER_SQL))
        .limit(MAX_ASSIGNED_ITEMS)
        .to_a

      new_count = new_scope.count

      items = assigned_records.map { |record| assigned_item(record) }
      items << grouped_new_item(new_count) if new_count.positive?

      Result.new(
        total: assigned_scope.count + new_count,
        items: items
      )
    end

    private

    def visible_scope(email)
      scope = AuditNotification.all

      return scope unless @restrict_to_queue

      scope.where(QUEUE_VISIBILITY_SQL, email)
    end

    def assigned_item(record)
      Item.new(
        kind: assigned_kind(record),
        title: assigned_title(record),
        hint: assigned_hint(record),
        path: Rails.application.routes.url_helpers.alert_path(record),
        category: humanize_label(record["categoriaAlerta"]),
        grouped: false
      )
    end

    def grouped_new_item(count)
      Item.new(
        kind: "new",
        title: new_title(count),
        hint: "Click para revisar",
        path: Rails.application.routes.url_helpers.alerts_path(
          asignacion: "sin_asignar",
          estado: "pendiente"
        ),
        category: nil,
        grouped: true
      )
    end

    def assigned_kind(record)
      severity = record["severidad"].to_s
      return severity if SEVERITY_LABELS.key?(severity)

      "assigned"
    end

    def assigned_title(record)
      severity = SEVERITY_LABELS[record["severidad"].to_s]
      return "Alerta #{severity} Asignada" if severity.present?

      "Alerta Asignada"
    end

    def assigned_hint(record)
      motivo = record["motivo"].to_s.squish
      return "Click para atender" if motivo.blank?

      motivo.truncate(MOTIVO_LIMIT)
    end

    def new_title(count)
      noun = count == 1 ? "Alerta Nueva" : "Alertas Nuevas"

      "#{count} #{noun}"
    end

    def humanize_label(value)
      text = value.to_s.tr("_-", " ").squish
      return if text.blank?

      text.downcase.sub(/\S/, &:upcase)
    end

    def viewer_email
      @viewer&.usuario.to_s.strip.downcase.presence
    end

    def empty_result
      Result.new(total: 0, items: [])
    end
  end
end
