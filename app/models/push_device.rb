class PushDevice < AuditRecord
  self.table_name = "push_devices"

  belongs_to :audit_user,
    class_name: "AuditUser",
    foreign_key: "user_id",
    inverse_of: :push_devices

  validates :token,
    presence: true,
    uniqueness: true

  validates :platform,
    presence: true,
    inclusion: {
      in: %w[web android ios]
    }

  scope :active, -> {
    where(active: true)
  }
end
