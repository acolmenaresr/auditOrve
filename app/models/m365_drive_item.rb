class M365DriveItem < AuditRecord
  self.table_name = "m365_drive_items"

  belongs_to :nomenclature_audit_run,
           class_name: "M365AuditRun",
           foreign_key: :nomenclature_last_audit_run_id,
           optional: true

  has_many :source_items,
         class_name: "M365SourceItem",
         foreign_key: :drive_item_id,
         inverse_of: :drive_item

  has_many :storage_sources,
         through: :source_items,
         source: :storage_source

  scope :active, -> { where(is_deleted: false) }
  scope :folders, -> { where(item_type: "folder") }
  scope :files, -> { where(item_type: "file") }
  scope :audited, -> { where.not(nomenclature_status: nil) }

  scope :compliant, lambda {
    where(nomenclature_status: "compliant")
  }

  scope :non_compliant, lambda {
    where(nomenclature_status: "non_compliant")
  }
end
