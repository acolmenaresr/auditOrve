class Microsoft365User < AuditRecord
  self.table_name = "users365catalog"

  has_many :m365_storage_sources,
            class_name: "M365StorageSource",
            foreign_key: :user_catalog_id,
            inverse_of: :microsoft365_user

  OFFICE_LICENSE_SKUS = %w[
    O365_BUSINESS_PREMIUM
    O365_BUSINESS_ESSENTIALS
    STANDARDPACK
  ].freeze

  def license_list
    licenses.is_a?(Array) ? licenses : []
  end

  def license_count
    license_list.length
  end

  def office_license?
    license_list.any? do |license|
      office_license_sku?(
        license_sku_part_number(license)
      )
    end
  end

  def commercial_license_names
    license_list.filter_map do |license|
      commercial_license_name(license)
    end.uniq
  end

  def activity_status
    return :disabled unless account_enabled
    return :without_activity if last_activity_date.blank?
    return :inactive if last_activity_date < 90.days.ago.to_date

    :active
  end

  private

  def office_license_sku?(sku_part_number)
    OFFICE_LICENSE_SKUS.include?(
      sku_part_number.to_s.strip.upcase
    )
  end

  def license_sku_part_number(license)
    return unless license.is_a?(Hash)

    license_data = license.stringify_keys

    license_data["skuPartNumber"].presence ||
      license_data["sku_part_number"].presence
  end

  def commercial_license_name(license)
    return license.to_s.strip.presence unless license.is_a?(Hash)

    license_data = license.stringify_keys

    license_data["commercialName"].presence ||
      license_data["commercial_name"].presence ||
      license_data["displayName"].presence ||
      license_data["display_name"].presence ||
      license_data["productName"].presence ||
      license_data["product_name"].presence ||
      license_data["skuPartNumber"].presence ||
      license_data["sku_part_number"].presence
  end
end
