class AuditNotification < AuditRecord
  self.table_name = "auditNotificaciones"
  self.primary_key = "id"

  STATUSES = %w[
    pendiente
    asignada
    en_revision
    resuelta
    descartada
  ].freeze

  IN_PROGRESS_STATUSES = %w[
    asignada
    en_revision
  ].freeze

  SEVERITIES = %w[
    critica
    alta
    media
    baja
  ].freeze

  def occurred_at
    self["dateZ"].presence || self["createdAt"]
  end

  def closed?
    %w[resuelta descartada].include?(self["estado"].to_s)
  end

  def in_progress?
    IN_PROGRESS_STATUSES.include?(self["estado"].to_s)
  end
end
