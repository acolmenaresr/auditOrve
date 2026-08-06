module NomenclatureAuditsHelper
  def cloudorve_drives_sort_path(column)
    next_direction =
      if @sort == column && @direction == "asc"
        "desc"
      else
        "asc"
      end

    cloudorve_drives_path(
      search: @search,
      scan_status: @scan_status,
      source_type: @source_type,
      per_page: @per_page,
      sort: column,
      direction: next_direction,
      page: 1
    )
  end

  def cloudorve_drives_sort_icon(column)
    return "↕" unless @sort == column

    @direction == "asc" ? "↑" : "↓"
  end

  def cloudorve_drives_sort_class(column)
    classes = [ "audit-sort-link" ]
    classes << "is-active" if @sort == column
    classes.join(" ")
  end

  def compliance_badge_class(value)
    status =
      if value.nil?
        "unknown"
      elsif value.to_d >= 90
        "success"
      elsif value.to_d >= 70
        "warning"
      else
        "danger"
      end

    [
      "compliance-badge",
      "compliance-badge--#{status}"
    ].join(" ")
  end

  def compliance_badge_text(value)
    return "Sin datos" if value.nil?

    percentage =
      number_with_precision(
        value,
        precision: 2,
        strip_insignificant_zeros: true
      )

    "#{percentage} %"
  end

  def drive_item_status_label(status)
    case status.to_s
    when "compliant"
      "Cumple"
    when "non_compliant"
      "No cumple"
    when "pending_review"
      "En revisión"
    when "excluded"
      "Excluido"
    when "no_applicable_rule"
      "Sin regla aplicable"
    else
      "Sin evaluar"
    end
  end

  def drive_item_status_class(status)
    modifier =
      case status.to_s
      when "compliant"
        "success"
      when "non_compliant"
        "danger"
      when "pending_review"
        "warning"
      when "excluded", "no_applicable_rule"
        "neutral"
      else
        "unknown"
      end

    [
      "drive-item-status",
      "drive-item-status--#{modifier}"
    ].join(" ")
  end

  def drive_item_has_children?(item)
    ActiveModel::Type::Boolean.new.cast(
      item.has_children
    )
  end
  def drive_item_failed_rule_messages(item)
  raw_rules =
    item.nomenclature_failed_rules

  parsed_rules =
    parse_drive_item_failed_rules(raw_rules)

  extract_drive_item_rule_messages(parsed_rules)
    .map(&:strip)
    .reject(&:blank?)
    .uniq
end

private

def parse_drive_item_failed_rules(raw_rules)
  return [] if raw_rules.blank?
  return raw_rules unless raw_rules.is_a?(String)

  JSON.parse(raw_rules)
rescue JSON::ParserError
  raw_rules
end

def extract_drive_item_rule_messages(value)
  case value
  when Array
    value.flat_map do |entry|
      extract_drive_item_rule_messages(entry)
    end

  when Hash
    normalized =
      value.stringify_keys

    preferred_value =
      normalized["message"] ||
      normalized["description"] ||
      normalized["rule_name"] ||
      normalized["ruleName"] ||
      normalized["name"] ||
      normalized["rule"]

    if preferred_value.present?
      extract_drive_item_rule_messages(
        preferred_value
      )
    else
      normalized.values.flat_map do |entry|
        extract_drive_item_rule_messages(entry)
      end
    end

  when String
    value.strip.present? ? [ value.strip ] : []

  else
    []
  end
end
end
