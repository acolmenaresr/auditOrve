class AuditUser < AuditRecord
  self.table_name = "users"
  self.primary_key = "id"

  def full_name
    [firstname, lastname].compact_blank.join(" ")
  end
  def first_name
    [firstname].compact_blank.join("")
  end
end