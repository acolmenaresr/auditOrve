class AuditMovement < AuditRecord
  self.table_name = "mv_audit_movements"
  self.primary_key = "movement_id"

  # Compatibilidad temporal con la UI existente.
  alias_attribute :dateZ, :occurred_at
  alias_attribute :fechaEv, :event_date
  alias_attribute :usuario, :user_name
  alias_attribute :tipoUsuario, :user_type
  alias_attribute :accion, :source_action
  alias_attribute :operacion365, :operation
  alias_attribute :aplicacion, :application
  alias_attribute :tipoItem, :item_type
  alias_attribute :archivo, :file_name
  alias_attribute :ruta, :path
  alias_attribute :sitio, :site_url

  def readonly?
    true
  end
end
