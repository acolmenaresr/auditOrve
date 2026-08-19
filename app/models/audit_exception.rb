class AuditException < AuditRecord
  self.table_name = "auditExcepciones"
  self.primary_key = "id"
end
