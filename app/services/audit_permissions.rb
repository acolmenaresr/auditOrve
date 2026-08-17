class AuditPermissions
  NONE = :none
  READ = :read
  MANAGE = :manage

  USER_365 = 1
  LA_365 = 2

  CLOUD_AUDITOR = 5
  EVENT_AUDITOR = 6
  MASTER_AUDITOR = 7
  DG = 8
  ADMIN = 9
  SUPER_ADMIN = 10

  # =========================================================
  # MATRIZ CENTRAL DE PERMISOS
  #
  # :none
  #   El módulo no existe para el usuario.
  #
  # :read
  #   Puede consultar el módulo, pero no realizar acciones
  #   operativas.
  #
  # :manage
  #   Puede consultar y realizar acciones operativas.
  #
  # Los tipos 1 a 4 no tienen acceso a los módulos actuales.
  # Sus vistas específicas se incorporarán posteriormente.
  # =========================================================

  PERMISSIONS = {
    CLOUD_AUDITOR => {
      events: NONE,
      cloud: MANAGE,
      users: NONE
    },

    EVENT_AUDITOR => {
      events: MANAGE,
      cloud: NONE,
      users: NONE
    },

    MASTER_AUDITOR => {
      events: MANAGE,
      cloud: MANAGE,
      users: NONE
    },

    DG => {
      events: READ,
      cloud: READ,
      users: READ
    },

    # Por ahora conservamos Admin únicamente para
    # administración de usuarios.
    ADMIN => {
      events: NONE,
      cloud: NONE,
      users: MANAGE
    },

    SUPER_ADMIN => {
      events: MANAGE,
      cloud: MANAGE,
      users: MANAGE
    }
  }.freeze


  def initialize(user)
    @user = user
  end


  # =========================================================
  # INFORMACIÓN DEL ROL
  # =========================================================

  def user_type_id
    @user&.tipoUsuario.to_i
  end


  def super_admin?
    user_type_id == SUPER_ADMIN
  end


  def admin?
    user_type_id == ADMIN
  end


  def dg?
    user_type_id == DG
  end


  def cloud_auditor?
    user_type_id == CLOUD_AUDITOR
  end


  def event_auditor?
    user_type_id == EVENT_AUDITOR
  end


  def master_auditor?
    user_type_id == MASTER_AUDITOR
  end


  # =========================================================
  # PERMISO GENÉRICO
  # =========================================================

  def permission_for(module_name)
    return MANAGE if super_admin?

    permissions_for_user.fetch(
      module_name.to_sym,
      NONE
    )
  end


  # =========================================================
  # EVENTOS
  # =========================================================

  def can_access_events?
    accessible?(:events)
  end


  def can_manage_events?
    manageable?(:events)
  end


  # =========================================================
  # CLOUD ORVE
  # =========================================================

  def can_access_cloud?
    accessible?(:cloud)
  end


  def can_manage_cloud?
    manageable?(:cloud)
  end


  # =========================================================
  # USUARIOS ADMINISTRATIVOS
  # =========================================================

  def can_access_users?
    accessible?(:users)
  end


  def can_manage_users?
    manageable?(:users)
  end


  # =========================================================
  # RUTAS INICIALES
  #
  # El usuario se envía únicamente a un módulo que realmente
  # puede conocer.
  # =========================================================

  def home_module
    return :events if can_access_events?
    return :cloud if can_access_cloud?
    return :users if can_access_users?

    nil
  end


  # =========================================================
  # CONSULTAS GENERALES
  # =========================================================

  def has_any_current_module?
    home_module.present?
  end


  def read_only?(module_name)
    permission_for(module_name) == READ
  end


  def manageable?(module_name)
    permission_for(module_name) == MANAGE
  end


  def accessible?(module_name)
    permission_for(module_name) != NONE
  end


  private


  def permissions_for_user
    PERMISSIONS.fetch(
      user_type_id,
      empty_permissions
    )
  end


  def empty_permissions
    {
      events: NONE,
      cloud: NONE,
      users: NONE
    }
  end
end
