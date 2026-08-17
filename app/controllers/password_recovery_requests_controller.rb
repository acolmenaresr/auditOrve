class PasswordRecoveryRequestsController < ApplicationController
  skip_before_action :require_authentication


  # =========================================================
  # FORMULARIO DE RECUPERACIÓN
  # =========================================================

  def new
  end


  # =========================================================
  # SOLICITAR RECUPERACIÓN DE CONTRASEÑA
  # =========================================================

  def create
    email =
      normalized_email

    unless valid_email?(
      email
    )
      flash.now[:alert] =
        "Ingresa un correo electrónico válido."

      return render(
        :new,
        status: :unprocessable_entity
      )
    end


    result =
      PasswordRecovery::RequestRecovery.new(
        email: email,
        ip: request.remote_ip,
        user_agent: request.user_agent
      ).call


    if result[:ok]
      redirect_to(
        forgot_password_path,
        notice: result[:message]
      )
    else
      flash.now[:alert] =
        result[:message]

      render(
        :new,
        status: :bad_gateway
      )
    end
  end


  private


  # =========================================================
  # NORMALIZAR CORREO
  # =========================================================

  def normalized_email
    params
      .dig(
        :password_recovery,
        :email
      )
      .to_s
      .strip
      .downcase
  end


  # =========================================================
  # VALIDAR CORREO
  # =========================================================

  def valid_email?(email)
    return false if email.blank?

    email.match?(
      URI::MailTo::EMAIL_REGEXP
    )
  end
end
