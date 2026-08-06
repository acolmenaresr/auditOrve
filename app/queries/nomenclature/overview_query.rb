module Nomenclature
  class OverviewQuery
    def call
      row = eligible_items
        .select(select_columns)
        .take

      {
        active_drives_count: eligible_sources.count,
        folders_count: row.folders_count.to_i,
        folders_compliance_percentage:
          numeric_value(row.folders_compliance_percentage),
        files_count: row.files_count.to_i,
        files_compliance_percentage:
          numeric_value(row.files_compliance_percentage),
        pending_items_count: row.pending_items_count.to_i,
        non_auditable_items_count:
          row.non_auditable_items_count.to_i
      }
    end

    private

    def eligible_sources
      @eligible_sources ||= M365StorageSource
        .left_joins(:microsoft365_user)
        .where(active: true)
        .where(
          <<~SQL.squish,
            (
              users365catalog.user_principal_name IS NULL
              OR LOWER(
                users365catalog.user_principal_name
              ) NOT IN (?)
            )
          SQL
          Nomenclature::ServiceAccounts::OWNER_UPNS
        )
    end

    def eligible_items
      M365SourceItem
        .joins(:drive_item)
        .where(
          source_id: eligible_sources.select(:id),
          m365_source_items: {
            is_deleted: false,
            is_root_item: false
          },
          m365_drive_items: {
            is_deleted: false
          }
        )
    end

    def select_columns
      [
        item_count_sql(
          "folder",
          "folders_count"
        ),
        compliance_percentage_sql(
          "folder",
          "folders_compliance_percentage"
        ),
        item_count_sql(
          "file",
          "files_count"
        ),
        compliance_percentage_sql(
          "file",
          "files_compliance_percentage"
        ),
        pending_items_count_sql,
        non_auditable_items_count_sql
      ]
    end

    def item_count_sql(item_type, alias_name)
      <<~SQL.squish
        COUNT(*)
        FILTER (
          WHERE m365_drive_items.item_type =
            #{quote(item_type)}
        ) AS #{alias_name}
      SQL
    end

    def compliance_percentage_sql(item_type, alias_name)
      quoted_item_type = quote(item_type)

      <<~SQL.squish
        ROUND(
          (
            COUNT(*)
            FILTER (
              WHERE m365_drive_items.item_type =
                #{quoted_item_type}
              AND m365_drive_items.nomenclature_status =
                'compliant'
            )::numeric * 100
          )
          /
          NULLIF(
            COUNT(*)
            FILTER (
              WHERE m365_drive_items.item_type =
                #{quoted_item_type}
              AND m365_drive_items.nomenclature_status IN (
                'compliant',
                'non_compliant'
              )
            ),
            0
          ),
          2
        ) AS #{alias_name}
      SQL
    end

    def pending_items_count_sql
      <<~SQL.squish
        COUNT(*)
        FILTER (
          WHERE
            m365_drive_items.nomenclature_status IS NULL
            OR m365_drive_items.nomenclature_status =
              'pending_review'
        ) AS pending_items_count
      SQL
    end

    def non_auditable_items_count_sql
      <<~SQL.squish
        COUNT(*)
        FILTER (
          WHERE m365_drive_items.nomenclature_status IN (
            'excluded',
            'no_applicable_rule'
          )
        ) AS non_auditable_items_count
      SQL
    end

    def numeric_value(value)
      return nil if value.nil?

      value.to_d
    end

    def quote(value)
      AuditRecord.connection.quote(value)
    end
  end
end
