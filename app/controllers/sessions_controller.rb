class SessionsController < ApplicationController
  skip_before_action :require_authentication,
                     only: %i[
                       new
                       create
                     ]


  # =========================================================
  # LOGIN
  # =========================================================

  def new
    redirect_to root_path if current_user
  end


  # =========================================================
  # CREAR SESIÓN
  # =========================================================

  def create
    user =
      AuditUser.find_by(
        usuario: normalized_usuario
      )


    unless user && valid_password?(user)
      flash.now[:alert] =
        "Usuario o contraseña incorrectos."

      return render(
        :new,
        status: :unprocessable_entity
      )
    end


    # =======================================================
    # VERIFICAR QUE EXISTA UNA VISTA IMPLEMENTADA
    # =======================================================

    unless authorized_home_path(user).present?
      flash.now[:alert] =
        "Tu perfil aún no tiene una vista habilitada."

      return render(
        :new,
        status: :unprocessable_entity
      )
    end


    # =======================================================
    # CREAR SESIÓN
    # =======================================================

    reset_session

    session[:audit_user_id] =
      user.id

    session[:authenticated_at] =
      Time.current.to_i

    update_last_login(user)

    session[:push_setup_pending] =
      push_alerts_required_for?(user)

    redirect_to(
      root_path,
      notice: "Sesión iniciada correctamente."
    )
  end


  # =========================================================
  # LOGOUT
  # =========================================================

  def destroy
    reset_session

    redirect_to(
      login_path,
      notice: "Sesión cerrada correctamente.",
      status: :see_other
    )
  end


  private


  # =========================================================
  # USUARIO
  # =========================================================

  def normalized_usuario
    params
      .dig(:session, :usuario)
      .to_s
      .strip
      .downcase
  end


  # =========================================================
  # PASSWORD
  # =========================================================

  def submitted_password
    params
      .dig(:session, :password)
      .to_s
  end


  def valid_password?(user)
    return false if submitted_password.blank?
    return false if user.password.blank?

    BCrypt::Password.new(
      user.password
    ) == submitted_password

  rescue BCrypt::Errors::InvalidHash
    false
  end


  # =========================================================
  # ÚLTIMO LOGIN
  # =========================================================

  def update_last_login(user)
    return unless user.has_attribute?(
      "lastLogin"
    )

    user.update_column(
      "lastLogin",
      Time.current
    )
  end
end
