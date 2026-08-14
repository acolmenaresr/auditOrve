class AuditUsersController < ApplicationController
  ALLOWED_USER_TYPES = [ 9, 10 ].freeze

  before_action :authorize_user_management

  def new
    load_user_types
  end

  def create
    load_user_types

    attributes = audit_user_params

    firstname = attributes[:firstname].to_s.strip
    lastname = attributes[:lastname].to_s.strip
    usuario = attributes[:usuario].to_s.strip.downcase
    tipo_usuario_id = attributes[:tipo_usuario_id].to_i

    unless valid_form?(
      firstname: firstname,
      lastname: lastname,
      usuario: usuario,
      tipo_usuario_id: tipo_usuario_id
    )
      flash.now[:alert] = "Completa correctamente todos los campos."

      return render :new,
                    status: :unprocessable_entity
    end

    result = AuditUsers::CreateUser.new(
      firstname: firstname,
      lastname: lastname,
      usuario: usuario,
      tipo_usuario_id: tipo_usuario_id
    ).call

    if result.success?
      redirect_to new_audit_user_path,
                  notice: result.message
    else
      flash.now[:alert] = result.message

      render :new,
             status: :unprocessable_entity
    end
  end

  private

  def audit_user_params
    params.expect(
      audit_user: %i[
        firstname
        lastname
        usuario
        tipo_usuario_id
      ]
    )
  end

  def load_user_types
    @user_types = AuditUserType.order(:id)
  end

  def valid_form?(
    firstname:,
    lastname:,
    usuario:,
    tipo_usuario_id:
  )
    return false if firstname.blank?
    return false if lastname.blank?
    return false if usuario.blank?
    return false unless usuario.match?(URI::MailTo::EMAIL_REGEXP)

    AuditUserType.exists?(id: tipo_usuario_id)
  end

  def authorize_user_management
    return if ALLOWED_USER_TYPES.include?(
      current_user["tipoUsuario"].to_i
    )

    redirect_to dashboard_path,
                alert: "No tienes permisos para administrar usuarios."
  end
end