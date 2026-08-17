class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :require_authentication

  helper_method :current_user,
                :authenticated?,
                :authenticated_shell?,
                :current_permissions,
                :authorized_home_path

  SESSION_DURATION = 8.hours

  PUBLIC_SHELL_CONTROLLERS = %w[
    sessions
    password_recovery_requests
    password_resets
  ].freeze


  private


  # =========================================================
  # USUARIO ACTUAL
  # =========================================================

  def current_user
    return @current_user if defined?(@current_user)

    @current_user =
      if session_valid?
        AuditUser.find_by(
          id: session[:audit_user_id]
        )
      end
  end


  # =========================================================
  # AUTENTICACIÓN
  # =========================================================

  def authenticated?
    current_user.present?
  end


  # =========================================================
  # SHELL AUTENTICADO
  #
  # Determina si la vista debe mostrar:
  #
  # - Topbar
  # - Sidebar
  # - Navegación interna
  #
  # Las pantallas relacionadas con autenticación y
  # recuperación de contraseña son deliberadamente públicas,
  # incluso si el navegador ya tiene una sesión activa.
  # =========================================================

  def authenticated_shell?
    authenticated? &&
      !PUBLIC_SHELL_CONTROLLERS.include?(
        controller_name
      )
  end


  def require_authentication
    return if authenticated?

    reset_session

    redirect_to(
      login_path,
      alert: "Inicia sesión para continuar."
    )
  end


  def session_valid?
    user_id =
      session[:audit_user_id]

    authenticated_at =
      session[:authenticated_at]

    return false if user_id.blank?
    return false if authenticated_at.blank?

    Time.at(
      authenticated_at.to_i
    ) >= SESSION_DURATION.ago
  end


  # =========================================================
  # PERMISOS
  # =========================================================

  def current_permissions
    return @current_permissions if defined?(@current_permissions)

    @current_permissions =
      AuditPermissions.new(
        current_user
      )
  end


  # =========================================================
  # HOME AUTORIZADO
  #
  # Esta es la única función que traduce un módulo autorizado
  # a una ruta Rails.
  #
  # No se utilizan IDs de tipo de usuario aquí.
  # =========================================================

  def authorized_home_path(user = current_user)
    return nil unless user

    permissions =
      AuditPermissions.new(
        user
      )

    case permissions.home_module
    when :events
      dashboard_path

    when :cloud
      cloudorve_path

    when :users
      # Actualmente todavía no existe audit_users#index.
      #
      # Admin y Super Admin pueden aterrizar en Usuario Nuevo
      # porque tienen permiso de gestión.
      return new_audit_user_path if permissions.can_manage_users?

      nil

    else
      nil
    end
  end


  # =========================================================
  # EVENTOS
  # =========================================================

  def authorize_events!
    return if current_permissions.can_access_events?

    render_not_found!
  end


  def authorize_events_management!
    return if current_permissions.can_manage_events?

    render_not_found!
  end


  # =========================================================
  # CLOUD ORVE
  # =========================================================

  def authorize_cloud!
    return if current_permissions.can_access_cloud?

    render_not_found!
  end


  def authorize_cloud_management!
    return if current_permissions.can_manage_cloud?

    render_not_found!
  end


  # =========================================================
  # USUARIOS
  # =========================================================

  def authorize_users!
    return if current_permissions.can_access_users?

    render_not_found!
  end


  def authorize_users_management!
    return if current_permissions.can_manage_users?

    render_not_found!
  end


  # =========================================================
  # 404 POR AUTORIZACIÓN
  # =========================================================

  def render_not_found!
    respond_to do |format|
      format.html do
        render(
          file: Rails.root.join(
            "public",
            "404.html"
          ),
          status: :not_found,
          layout: false
        )
      end

      format.json do
        head :not_found
      end

      format.any do
        head :not_found
      end
    end
  end
end
