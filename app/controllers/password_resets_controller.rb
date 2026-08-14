require "bcrypt"

class PasswordResetsController < ApplicationController
  skip_before_action :require_authentication

  def edit
    @token = normalized_token

    if @token.blank?
      @token_valid = false
      @error_message = "El enlace de recuperación no es válido."
      return
    end

    validation = validate_reset_token

    @token_valid = validation["valid"] == true

    if @token_valid
      assign_user_data(validation)
    else
      @error_message =
        "El enlace de recuperación expiró, ya fue utilizado o no es válido."
    end
  rescue AuditUsers::PasswordReset::RequestError => e
    Rails.logger.error(
      "Password reset validation failed: #{e.class}: #{e.message}"
    )

    @token_valid = false
    @error_message =
      "No fue posible validar el enlace de recuperación. Intenta nuevamente."
  end

  def update
    @token = normalized_token

    validation = validate_reset_token

    unless validation["valid"] == true
      @token_valid = false
      @error_message =
        "El enlace de recuperación expiró, ya fue utilizado o no es válido."

      return render :edit, status: :unprocessable_entity
    end

    @token_valid = true
    assign_user_data(validation)

    password = params[:password].to_s
    confirmation = params[:password_confirmation].to_s

    validation_message =
      password_validation_message(
        password,
        confirmation
      )

    if validation_message.present?
      @error_message = validation_message

      return render :edit, status: :unprocessable_entity
    end

    password_hash =
      BCrypt::Password.create(
        password,
        cost: 10
      ).to_s

    result =
      AuditUsers::PasswordReset.update_password(
        token: @token,
        password_hash: password_hash,
        user_id: validation["userid"]
      )

    unless result["ok"] == true
      @error_message =
        result["message"].presence ||
        "No fue posible actualizar la contraseña."

      return render :edit, status: :unprocessable_entity
    end

    redirect_to(
      login_path,
      notice: "Contraseña actualizada correctamente. Ya puedes iniciar sesión."
    )
  rescue AuditUsers::PasswordReset::RequestError => e
    Rails.logger.error(
      "Password reset update failed: #{e.class}: #{e.message}"
    )

    @token_valid = false
    @error_message =
      "No fue posible actualizar la contraseña. Intenta nuevamente."

    render :edit, status: :service_unavailable
  end

  private

  def normalized_token
    params[:token].to_s.strip
  end

  def validate_reset_token
    return { "valid" => false } if @token.blank?

    AuditUsers::PasswordReset.validate(
      token: @token
    )
  end

  def assign_user_data(validation)
    @reset_user = {
      id: validation["userid"],
      email: validation["usuario"],
      firstname: validation["firstname"],
      lastname: validation["lastname"],
      expires_at: validation["expires_at"]
    }
  end

  def password_validation_message(
    password,
    confirmation
  )
    return "Ingresa una nueva contraseña." if password.blank?

    if password.length < 8
      return "La contraseña debe tener al menos 8 caracteres."
    end

    unless password.match?(/[A-Z]/)
      return "La contraseña debe contener al menos una letra mayúscula."
    end

    unless password.match?(/[a-z]/)
      return "La contraseña debe contener al menos una letra minúscula."
    end

    unless password.match?(/[^A-Za-z0-9]/)
      return "La contraseña debe contener al menos un carácter especial."
    end

    if confirmation.blank?
      return "Confirma la nueva contraseña."
    end

    unless password == confirmation
      return "Las contraseñas no coinciden."
    end

    nil
  end
end
