class M365AuditRun < AuditRecord
  self.table_name = "m365_audit_runs"

  belongs_to :storage_source,
             class_name: "M365StorageSource",
             foreign_key: :source_id,
             inverse_of: :audit_runs

  scope :recent, lambda {
    order(started_at: :desc, id: :desc)
  }
end