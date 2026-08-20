module ApplicationHelper
  # =========================================================
  # CONTEXTO DE NAVEGACIÓN
  # =========================================================

  def app_section_name
    case controller_name
    when "dashboard",
         "audit_logs",
         "audit_notifications",
         "users365"
      "Eventos"

    when "nomenclature_audits"
      "Cloud Orve"

    when "audit_users"
      "Usuarios"

    else
      "AuditORVE"
    end
  end


  def app_page_title
    case controller_name
    when "dashboard"
      "Dashboard"

    when "audit_notifications"
      action_name == "show" ? "Detalle de alerta" : "Alertas"

    when "audit_logs"
      "Movimientos"

    when "users365"
      action_name == "show" ?
        "Detalle de usuario" :
        "Usuarios"

    when "nomenclature_audits"
      case action_name
      when "index"
        "Dashboard"

      when "drives"
        "Clouds"

      when "show",
           "children"
        "Detalle de Cloud"

      else
        "Cloud Orve"
      end

    when "audit_users"
      case action_name
      when "new",
           "create"
        "Usuario Nuevo"

      when "index"
        "Dashboard"

      else
        "Usuarios"
      end

    else
      "AuditORVE"
    end
  end


  def app_document_title
    "#{app_page_title} | AuditORVE"
  end


  # =========================================================
  # DATOS VISUALES DEL USUARIO
  #
  # Estos métodos solamente presentan información.
  # No toman decisiones de autorización.
  # =========================================================

  def current_user_display_name
    return "" unless current_user

    current_user.full_name.presence ||
      current_user.usuario
  end


  def current_user_short_name
    return "" unless current_user

    first_names =
      current_user
        .firstname
        .to_s
        .strip
        .split
        .join(" ")

    first_last_name =
      current_user
        .lastname
        .to_s
        .strip
        .split
        .first
        .to_s

    name =
      [
        first_names,
        first_last_name
      ]
      .reject(&:blank?)
      .join(" ")

    name.presence ||
      current_user.usuario
  end


  def current_user_initials
    return "U" unless current_user

    first =
      current_user
        .firstname
        .to_s
        .strip
        .first

    last =
      current_user
        .lastname
        .to_s
        .strip
        .first

    initials =
      "#{first}#{last}"
        .strip
        .upcase

    return initials if initials.present?

    current_user
      .usuario
      .to_s
      .strip
      .first(2)
      .upcase
      .presence ||
      "U"
  end


  # =========================================================
  # ETIQUETA DEL TIPO DE USUARIO
  #
  # IMPORTANTE:
  #
  # tipoUsuario sí puede consultarse aquí porque únicamente
  # estamos obteniendo el nombre visual del rol.
  #
  # NO utilizamos este valor para conceder o denegar acceso.
  # =========================================================

  def current_user_type_label
    return "Sin tipo asignado" unless current_user

    user_type_id =
      current_user
        .tipoUsuario
        .to_i

    return "Sin tipo asignado" if user_type_id.zero?

    user_type =
      AuditUserType.find_by(
        id: user_type_id
      )

    user_type&.label.presence ||
      "Tipo #{user_type_id}"
  end


  # =========================================================
  # USUARIO ANÓNIMO (ETIQUETA DE VISUALIZACIÓN)
  # =========================================================

  ANONYMOUS_USER_DISPLAY_LABEL = "Usuario anónimo".freeze

  ANONYMOUS_USER_LABELS = [
    "anonimo",
    "anónimo",
    "usuario anonimo",
    "usuario anónimo"
  ].freeze

  def anonymous_audit_user?(value)
    ANONYMOUS_USER_LABELS.include?(
      value.to_s.squish.downcase
    )
  end

  def audit_user_display_label(value)
    text = value.to_s.squish
    return "Sin usuario" if text.blank?
    return ANONYMOUS_USER_DISPLAY_LABEL if anonymous_audit_user?(text)

    text
  end


  # =========================================================
  # INBOX DE ALERTAS (CAMPANA)
  # =========================================================

  def alerts_inbox
    return @alerts_inbox if defined?(@alerts_inbox)

    unless authenticated? &&
        current_permissions.can_access_events?
      return @alerts_inbox = nil
    end

    @alerts_inbox =
      AuditNotifications::InboxSummary.new(
        viewer: current_user,
        restrict_to_queue: current_permissions.event_auditor?
      ).call
  rescue StandardError => error
    Rails.logger.error(
      "[AlertsInbox] #{error.class}: #{error.message}"
    )

    @alerts_inbox = nil
  end
end
