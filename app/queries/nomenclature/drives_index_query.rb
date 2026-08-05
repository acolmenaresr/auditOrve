module Nomenclature
  class DrivesIndexQuery
    ELIGIBLE_ITEM_SQL = <<~SQL.squish.freeze
      m365_source_items.is_deleted = FALSE
      AND m365_source_items.is_root_item = FALSE
      AND m365_drive_items.is_deleted = FALSE
    SQL

    def initialize(scope: M365StorageSource.all)
      @scope = scope
    end

    def call
      scope
        .left_joins(
          :microsoft365_user,
          source_items: :drive_item
        )
        .where(m365_storage_sources: { active: true })
        .select(select_columns)
        .group(group_columns)
        .order(:source_name)
    end

    private

    attr_reader :scope

    def select_columns
      [
        "m365_storage_sources.id",
        "m365_storage_sources.source_name",
        "m365_storage_sources.source_type",
        "m365_storage_sources.scan_status",
        "m365_storage_sources.last_successful_scan_at",
        "users365catalog.id AS owner_id",
        "users365catalog.display_name AS owner_name",
        "users365catalog.user_principal_name AS owner_upn",
        count_sql(
          "folder",
          nil,
          "folders_count"
        ),
        count_sql(
          "file",
          nil,
          "files_count"
        ),
        count_sql(
          "folder",
          "compliant",
          "compliant_folders_count"
        ),
        count_sql(
          "folder",
          "non_compliant",
          "non_compliant_folders_count"
        ),
        count_sql(
          "file",
          "compliant",
          "compliant_files_count"
        ),
        count_sql(
          "file",
          "non_compliant",
          "non_compliant_files_count"
        ),
        compliance_percentage_sql(
          "folder",
          "folders_compliance_percentage"
        ),
        compliance_percentage_sql(
          "file",
          "files_compliance_percentage"
        ),
        pending_count_sql(
          "pending_items_count"
        ),
        non_auditable_count_sql(
          "non_auditable_items_count"
        ),
        last_evaluated_at_sql
      ]
    end

    def group_columns
      [
        "m365_storage_sources.id",
        "m365_storage_sources.source_name",
        "m365_storage_sources.source_type",
        "m365_storage_sources.scan_status",
        "m365_storage_sources.last_successful_scan_at",
        "users365catalog.id",
        "users365catalog.display_name",
        "users365catalog.user_principal_name"
      ]
    end

    def count_sql(item_type, status, alias_name)
      conditions = [
        ELIGIBLE_ITEM_SQL,
        "m365_drive_items.item_type = #{quote(item_type)}"
      ]

      if status
        conditions << <<~SQL.squish
          m365_drive_items.nomenclature_status =
          #{quote(status)}
        SQL
      end

      <<~SQL.squish
        COUNT(m365_drive_items.id)
        FILTER (
          WHERE #{conditions.join(" AND ")}
        ) AS #{alias_name}
      SQL
    end

    def compliance_percentage_sql(item_type, alias_name)
      quoted_item_type = quote(item_type)

      <<~SQL.squish
        ROUND(
          (
            COUNT(m365_drive_items.id)
            FILTER (
              WHERE #{ELIGIBLE_ITEM_SQL}
              AND m365_drive_items.item_type =
                #{quoted_item_type}
              AND m365_drive_items.nomenclature_status =
                'compliant'
            )::numeric * 100
          )
          /
          NULLIF(
            COUNT(m365_drive_items.id)
            FILTER (
              WHERE #{ELIGIBLE_ITEM_SQL}
              AND m365_drive_items.item_type =
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

    def pending_count_sql(alias_name)
      <<~SQL.squish
        COUNT(m365_drive_items.id)
        FILTER (
          WHERE #{ELIGIBLE_ITEM_SQL}
          AND (
            m365_drive_items.nomenclature_status IS NULL
            OR m365_drive_items.nomenclature_status =
              'pending_review'
          )
        ) AS #{alias_name}
      SQL
    end

    def non_auditable_count_sql(alias_name)
      <<~SQL.squish
        COUNT(m365_drive_items.id)
        FILTER (
          WHERE #{ELIGIBLE_ITEM_SQL}
          AND m365_drive_items.nomenclature_status IN (
            'excluded',
            'no_applicable_rule'
          )
        ) AS #{alias_name}
      SQL
    end

    def last_evaluated_at_sql
      <<~SQL.squish
        MAX(m365_drive_items.nomenclature_evaluated_at)
        FILTER (
          WHERE #{ELIGIBLE_ITEM_SQL}
        ) AS last_evaluated_at
      SQL
    end

    def quote(value)
      AuditRecord.connection.quote(value)
    end
  end
end