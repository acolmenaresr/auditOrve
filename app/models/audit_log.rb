class AuditLog < AuditRecord
  self.table_name = "auditLogs"
  self.primary_key = "id"
end
