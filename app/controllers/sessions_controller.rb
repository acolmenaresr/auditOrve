class SessionsController < ApplicationController
  skip_before_action :require_authentication, only: %i[new create]

  def new
    redirect_to root_path if current_user
  end

  def create
    user = AuditUser.find_by(
      usuario: normalized_usuario
    )

    if user && valid_password?(user)
      reset_session

      session[:audit_user_id] = user.id
      session[:authenticated_at] = Time.current.to_i

      update_last_login(user)

      redirect_to root_path,
                  notice: "Sesión iniciada correctamente."
    else
      flash.now[:alert] = "Usuario o contraseña incorrectos."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session

    redirect_to login_path,
                notice: "Sesión cerrada correctamente.",
                status: :see_other
  end

  private

  def normalized_usuario
    params.dig(:session, :usuario)
      .to_s
      .strip
      .downcase
  end

  def submitted_password
    params.dig(:session, :password).to_s
  end

  def valid_password?(user)
    return false if submitted_password.blank?
    return false if user.password.blank?

    BCrypt::Password.new(user.password) == submitted_password
  rescue BCrypt::Errors::InvalidHash
    false
  end

  def update_last_login(user)
    return unless user.has_attribute?("lastLogin")

    user.update_column("lastLogin", Time.current)
  end
end
