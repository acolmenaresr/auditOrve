module Nomenclature
  class DriveTreeChildrenQuery
    def initialize(source:, parent_item_id: nil)
      @source = source
      @parent_item_id =
        parent_item_id.to_s.strip.presence
    end

    def call
      source_items
        .joins(:drive_item)
        .where(
          m365_drive_items: {
            is_deleted: false,
            parent_item_id: resolved_parent_item_id
          }
        )
        .select(select_columns)
        .reorder(order_clause)
    end

    private

    attr_reader :source,
                :parent_item_id

    def source_items
      M365SourceItem.where(
        source_id: source.id,
        is_deleted: false,
        is_root_item: false
      )
    end

    def resolved_parent_item_id
      @resolved_parent_item_id ||=
        parent_item_id ||
        source.root_item_id.presence ||
        root_item_id_from_source_items
    end

    def root_item_id_from_source_items
      item_id = M365SourceItem
        .joins(:drive_item)
        .where(
          source_id: source.id,
          is_deleted: false,
          is_root_item: true,
          m365_drive_items: {
            is_deleted: false
          }
        )
        .pick(
          "m365_drive_items.item_id"
        )

      raise ActiveRecord::RecordNotFound if item_id.blank?

      item_id
    end

    def select_columns
      [
        "m365_source_items.id AS source_item_id",
        "m365_source_items.depth",
        "m365_source_items.full_path",
        "m365_source_items.relative_path",
        "m365_drive_items.id AS drive_item_id",
        "m365_drive_items.drive_id",
        "m365_drive_items.item_id",
        "m365_drive_items.parent_item_id",
        "m365_drive_items.name",
        "m365_drive_items.item_type",
        "m365_drive_items.nomenclature_status",
        "m365_drive_items.nomenclature_compliant",
        "m365_drive_items.nomenclature_total_rules",
        "m365_drive_items.nomenclature_compliant_rules",
        "m365_drive_items.nomenclature_non_compliant_rules",
        "m365_drive_items.nomenclature_no_applicable_rules",
        "m365_drive_items.nomenclature_excluded_rules",
        "m365_drive_items.nomenclature_pending_review_count",
        "m365_drive_items.nomenclature_failed_rules",
        "m365_drive_items.nomenclature_pending_review_rules",
        "m365_drive_items.nomenclature_evaluated_at",
        has_children_sql
      ]
    end

    def has_children_sql
      <<~SQL.squish
        EXISTS (
          SELECT 1
          FROM m365_source_items child_source_item
          INNER JOIN m365_drive_items child_drive_item
            ON child_drive_item.id =
              child_source_item.drive_item_id
          WHERE child_source_item.source_id =
            m365_source_items.source_id
          AND child_source_item.is_deleted = FALSE
          AND child_source_item.is_root_item = FALSE
          AND child_drive_item.is_deleted = FALSE
          AND child_drive_item.drive_id =
            m365_drive_items.drive_id
          AND child_drive_item.parent_item_id =
            m365_drive_items.item_id
        ) AS has_children
      SQL
    end

    def order_clause
      Arel.sql(
        <<~SQL.squish
          CASE
            WHEN m365_drive_items.item_type = 'folder'
              THEN 0
            ELSE 1
          END ASC,
          LOWER(m365_drive_items.name) ASC,
          m365_drive_items.id ASC
        SQL
      )
    end
  end
end
