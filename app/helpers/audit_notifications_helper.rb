module AuditNotificationsHelper
  STATUS_LABELS = {
    "pendiente" => "Pendiente",
    "asignada" => "Asignada",
    "en_revision" => "En revisión",
    "en_trabajo" => "En trabajo",
    "activas" => "Activas",
    "finalizadas" => "Finalizadas",
    "resuelta" => "Atendida",
    "descartada" => "Descartada"
  }.freeze

  SEVERITY_LABELS = {
    "critica" => "Crítica",
    "alta" => "Alta",
    "media" => "Media",
    "baja" => "Baja"
  }.freeze

  def alert_status_label(value)
    key = value.to_s
    key = "en_trabajo" if key == "en_revision"

    STATUS_LABELS.fetch(key, value.presence || "—")
  end

  def alert_severity_label(value)
    SEVERITY_LABELS.fetch(value.to_s, value.presence || "—")
  end

  def alert_type_label(value)
    value.to_s.tr("_", " ").downcase.capitalize.presence || "—"
  end

  def alert_motive_filter_label(value, limit: 42)
    text = value.to_s.squish
    return "—" if text.blank?

    text.length > limit ? "#{text[0, limit - 1]}…" : text
  end

  def alert_table_datetime(value)
    return "—" if value.blank?

    time = value.in_time_zone("America/Mexico_City")

    safe_join(
      [
        tag.strong(time.strftime("%d/%m/%y")),
        tag.small(time.strftime("%H:%M"))
      ]
    )
  end

  def alert_filter_path(overrides = {})
    params = request.query_parameters.merge(
      overrides.stringify_keys
    )

    overrides.each do |key, value|
      params.delete(key.to_s) if value.blank?
    end

    params["page"] = "1"
    alerts_path(params)
  end

  def alert_assignment_filter_options
    default_label =
      if current_permissions.event_auditor?
        "Mías y sin asignar"
      else
        "Todas"
      end

    options = [
      [ default_label, "" ],
      [ "Sin asignar", "sin_asignar" ],
      [ "Asignar a mí", "mias" ]
    ]

    agents = Array(@assignable_alert_users)
    agents.each do |user|
      next if assigned_to_current_user?(user)

      options << [ alert_user_display_name(user), user.id.to_s ]
    end

    options
  end

  def alert_metric_card_class(filter_key, filter_value)
    active =
      case filter_key
      when :estado
        @status.to_s == filter_value.to_s ||
          @alert_status.to_s == filter_value.to_s
      when :severidad
        @severity.to_s == filter_value.to_s ||
          @alert_severity.to_s == filter_value.to_s
      when :all
        (@status.blank? && @severity.blank?) &&
          (@alert_status.blank? && @alert_severity.blank?)
      else
        false
      end

    [
      "metric-card",
      "metric-card--link",
      ("is-active" if active)
    ].compact.join(" ")
  end

  def user_alert_filter_path(overrides = {})
    params = request.query_parameters.merge(
      overrides.stringify_keys
    )

    overrides.each do |key, value|
      params.delete(key.to_s) if value.blank?
    end

    params["alerts_page"] = "1"
    user365_path(@user, params)
  end

  def alert_assignee_options(users)
    users
      .sort_by { |user| assigned_to_current_user?(user) ? 0 : 1 }
      .map do |user|
        [ alert_assignee_option_label(user), user.id ]
      end
  end

  def alert_assignee_option_label(user)
    if assigned_to_current_user?(user)
      "Asignar a mí"
    else
      alert_user_display_name(user)
    end
  end

  def alert_assignee_display_name(record, users = [])
    email = record["asignadoA"].to_s.strip
    return "Sin asignar" if email.blank?

    user = users.find { |candidate|
      candidate.usuario.to_s.strip.downcase == email.downcase
    }

    if assigned_to_current_user?(user)
      "Asignar a mí"
    else
      alert_user_display_name(user)
    end
  end

  def assigned_to_current_user?(user)
    user.present? &&
      current_user.present? &&
      user.id == current_user.id
  end

  def alert_user_display_name(user)
    return "Usuario" if user.blank?

    user.full_name.presence ||
      user.first_name.presence ||
      "Usuario"
  end

  def selected_alert_assignee_id(record, users)
    email = record["asignadoA"].to_s.strip.downcase
    return if email.blank?

    users.find { |user|
      user.usuario.to_s.strip.downcase == email
    }&.id
  end
end
