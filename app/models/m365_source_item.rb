class M365SourceItem < AuditRecord
  self.table_name = "m365_source_items"

  belongs_to :storage_source,
             class_name: "M365StorageSource",
             foreign_key: :source_id,
             inverse_of: :source_items

  belongs_to :drive_item,
             class_name: "M365DriveItem",
             foreign_key: :drive_item_id,
             inverse_of: :source_items

  scope :active, -> { where(is_deleted: false) }

  scope :ordered, lambda {
    order(:depth, :relative_path, :id)
  }
end
