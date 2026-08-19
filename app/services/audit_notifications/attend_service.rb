module AuditNotifications
  class AttendService
    Result = Struct.new(:ok, :error, keyword_init: true)

    def initialize(
      notification:,
      actor:,
      action:,
      comment: nil,
      create_exception: false,
      exception_reason: nil,
      assignee_id: nil
    )
      @notification = notification
      @actor = actor
      @action = action.to_s
      @comment = comment.to_s.strip
      @create_exception = ActiveModel::Type::Boolean.new.cast(create_exception)
      @exception_reason = exception_reason.to_s.strip
      @assignee_id = assignee_id
    end

    def call
      return failure("La alerta ya fue atendida.") if already_closed?
      return assign if @action == "asignar"
      return add_comment if @action == "comentario"
      return complete if @action == "terminado"

      failure("Acción no válida.")
    end

    private

    def already_closed?
      %w[resuelta descartada].include?(@notification["estado"].to_s)
    end

    def assign
      assignee = eligible_assignee
      return assignee if assignee.is_a?(Result)

      @notification.update_columns(
        "estado" => "en_revision",
        "asignadoA" => assignee.usuario.to_s,
        "requiereSeguimiento" => true,
        "updatedAt" => Time.current
      )

      success
    end

    def add_comment
      return failure("El comentario es obligatorio.") if @comment.blank?

      now = Time.current
      attributes = {
        "comentarioRevision" => @comment,
        "resolucion" => @comment,
        "requiereSeguimiento" => true,
        "updatedAt" => now
      }

      unless @notification.in_progress?
        attributes["estado"] = "en_revision"
        attributes["asignadoA"] =
          @notification["asignadoA"].presence || actor_email
      end

      @notification.update_columns(attributes)
      success
    end

    def complete
      return failure("El comentario de resolución es obligatorio.") if @comment.blank?

      if @create_exception && @exception_reason.blank?
        return failure("Indica el motivo para eximir el movimiento.")
      end

      now = Time.current

      attributes = {
        "estado" => "resuelta",
        "resolucion" => @comment,
        "comentarioRevision" => @comment,
        "revisadoPor" => actor_email,
        "tratadoPor" => actor_email,
        "fechaRevision" => now,
        "fechaTratamiento" => now,
        "requiereRevision" => false,
        "requiereSeguimiento" => false,
        "tipoTratamiento" => @create_exception ? "excepcion" : "resuelto",
        "updatedAt" => now
      }

      if @notification["asignadoA"].blank?
        attributes["asignadoA"] = actor_email
      end

      create_exception_record! if @create_exception

      @notification.update_columns(attributes)
      success
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.to_sentence)
    end

    def eligible_assignee
      permissions = AuditPermissions.new(@actor)

      unless permissions.can_assign_alerts?
        return failure("No puedes asignar alertas.")
      end

      assignee = AuditUser.find_by(id: @assignee_id)

      if assignee.blank?
        return failure("Selecciona un usuario para asignar.")
      end

      assignee_type = assignee.tipoUsuario.to_i
      actor_type = permissions.user_type_id

      unless assignee_type >= AuditPermissions::EVENT_AUDITOR &&
          assignee_type <= actor_type
        return failure("No puedes asignar a ese usuario.")
      end

      assignee
    end

    def create_exception_record!
      operation = @notification["operacion365"].to_s.strip
      operation = "FileDownloaded" if operation.blank?

      exception = AuditException.new
      exception["archivo"] = @notification["archivo"]
      exception["usuario"] = @notification["usuario"]
      exception["operacion365"] = operation
      exception["motivo"] = @exception_reason
      exception["autorizadoPor"] = actor_email
      exception["activo"] = true
      exception["fechaInicio"] = Time.current
      exception.save!
    end

    def actor_email
      @actor.usuario.to_s
    end

    def success
      Result.new(ok: true, error: nil)
    end

    def failure(message)
      Result.new(ok: false, error: message)
    end
  end
end
