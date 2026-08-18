class AuditUser < AuditRecord
  self.table_name = "users"
  self.primary_key = "id"

  belongs_to :audit_user_type,
    class_name: "AuditUserType",
    foreign_key: "tipoUsuario",
    primary_key: "id",
    optional: true

  has_many :push_devices,
    class_name: "PushDevice",
    foreign_key: "user_id",
    inverse_of: :audit_user,
    dependent: :destroy

  def full_name
    [
      firstname,
      lastname
    ].compact_blank.join(" ")
  end

  def first_name
    firstname.to_s.strip
  end

  def user_type_label
    audit_user_type&.label.presence ||
      "Sin tipo asignado"
  end
end
