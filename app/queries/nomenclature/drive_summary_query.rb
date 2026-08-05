module Nomenclature
  class DriveSummaryQuery
    def initialize(source:)
      @source = source
    end

    def call
      counts = grouped_counts
      owner = source.microsoft365_user

      {
        source_id: source.id,
        source_name: source.source_name,
        source_type: source.source_type,
        owner_id: owner&.id,
        owner_name: owner&.display_name,
        owner_upn: owner&.user_principal_name,
        total_items: counts.values.sum,
        folders: metrics_for(counts, "folder"),
        files: metrics_for(counts, "file"),
        last_evaluated_at: last_evaluated_at
      }
    end

    private

    attr_reader :source

    def grouped_counts
      base_relation
        .group(:item_type, :nomenclature_status)
        .count
    end
    def last_evaluated_at
  base_relation.maximum(:nomenclature_evaluated_at)
end

    def base_relation
      M365DriveItem
        .joins(:source_items)
        .where(
          m365_source_items: {
            source_id: source.id,
            is_deleted: false,
            is_root_item: false
          },
          m365_drive_items: {
            is_deleted: false
          }
        )
    end

    def metrics_for(counts, item_type)
      compliant = status_count(
        counts,
        item_type,
        "compliant"
      )

      non_compliant = status_count(
        counts,
        item_type,
        "non_compliant"
      )

      pending = status_count(
        counts,
        item_type,
        nil
      ) + status_count(
        counts,
        item_type,
        "pending_review"
      )

      non_auditable = status_count(
        counts,
        item_type,
        "excluded"
      ) + status_count(
        counts,
        item_type,
        "no_applicable_rule"
      )

      auditable = compliant + non_compliant

      {
        total: total_for(counts, item_type),
        compliant: compliant,
        non_compliant: non_compliant,
        pending: pending,
        non_auditable: non_auditable,
        auditable: auditable,
        compliance_percentage: percentage(
          compliant,
          auditable
        )
      }
    end

    def status_count(counts, item_type, status)
      counts.fetch([item_type, status], 0)
    end

    def total_for(counts, item_type)
      counts.sum do |(grouped_type, _status), count|
        grouped_type == item_type ? count : 0
      end
    end

    def percentage(compliant, auditable)
      return nil if auditable.zero?

      (compliant.fdiv(auditable) * 100).round(2)
    end
  end
end