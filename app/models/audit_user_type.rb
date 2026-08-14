class AuditUserType < AuditRecord
  self.table_name = "tiposUsuario"
  self.primary_key = "id"

  def label
    self["tipoUsuario"].to_s
  end
end

