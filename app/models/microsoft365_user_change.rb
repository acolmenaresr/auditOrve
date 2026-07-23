class Microsoft365UserChange < AuditRecord
  self.table_name = "users365catalog_changes"
  self.primary_key = "id"

  belongs_to :catalog_user,
             class_name: "Microsoft365User",
             foreign_key: :catalog_user_id,
             inverse_of: :catalog_changes,
             optional: true
end
