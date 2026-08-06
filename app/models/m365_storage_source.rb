class M365StorageSource < AuditRecord
  self.table_name = "m365_storage_sources"

  belongs_to :microsoft365_user,
             class_name: "Microsoft365User",
             foreign_key: :user_catalog_id,
             inverse_of: :m365_storage_sources,
             optional: true

  has_many :source_items,
           class_name: "M365SourceItem",
           foreign_key: :source_id,
           inverse_of: :storage_source

  has_many :drive_items,
         through: :source_items,
         source: :drive_item
  has_many :audit_runs,
         class_name: "M365AuditRun",
         foreign_key: :source_id,
         inverse_of: :storage_source
end
