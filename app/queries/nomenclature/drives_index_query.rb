module Nomenclature
  class DrivesIndexQuery
    DEFAULT_PAGE = 1
    DEFAULT_PAGE_SIZE = 10
    MAX_PAGE_SIZE = 100

    DEFAULT_SORT = "name"
    DEFAULT_DIRECTION = "asc"

    SORT_COLUMNS = {
      "name" => <<~SQL.squish,
        LOWER(m365_storage_sources.source_name)
      SQL
      "owner" => <<~SQL.squish,
        LOWER(
          COALESCE(
            users365catalog.display_name,
            users365catalog.user_principal_name,
            ''
          )
        )
      SQL
      "folders_count" => "folders_count",
      "folders_compliance" =>
        "folders_compliance_percentage",
      "files_count" => "files_count",
      "files_compliance" =>
        "files_compliance_percentage",
      "pending" => "pending_items_count",
      "non_auditable" =>
        "non_auditable_items_count",
      "last_evaluated_at" =>
        "last_evaluated_at"
    }.freeze

    DIRECTIONS = %w[
      asc
      desc
    ].freeze

    ELIGIBLE_ITEM_SQL = <<~SQL.squish.freeze
      m365_source_items.is_deleted = FALSE
      AND m365_source_items.is_root_item = FALSE
      AND m365_drive_items.is_deleted = FALSE
    SQL

    attr_reader :search,
                :scan_status,
                :source_type,
                :page,
                :page_size,
                :sort,
                :direction

    def initialize(
      scope: M365StorageSource.all,
      search: nil,
      scan_status: nil,
      source_type: nil,
      page: DEFAULT_PAGE,
      page_size: DEFAULT_PAGE_SIZE,
      sort: DEFAULT_SORT,
      direction: DEFAULT_DIRECTION,
      owner_upns: nil,
      excluded_owner_upns: nil
    )
      @scope = scope
      @search = normalize_filter(search)
      @scan_status = normalize_filter(scan_status)
      @source_type = normalize_filter(source_type)
      @page = normalize_page(page)
      @page_size = normalize_page_size(page_size)
      @sort = normalize_sort(sort)
      @direction = normalize_direction(
        direction,
        raw_sort: sort
      )
      @owner_upns = normalize_owner_upns(owner_upns)
      @excluded_owner_upns =
        normalize_owner_upns(excluded_owner_upns)
    end

    def call
      records
    end

    def records
      @records ||= aggregated_scope
        .limit(page_size)
        .offset(offset)
    end

    def total_count
      @total_count ||= filtered_sources_scope.count(
        "m365_storage_sources.id"
      )
    end

    def total_pages
      return 1 if total_count.zero?

      (total_count.to_f / page_size).ceil
    end

    private

    attr_reader :scope,
                :owner_upns,
                :excluded_owner_upns

    def filtered_sources_scope
      @filtered_sources_scope ||= begin
        relation = scope
          .left_joins(:microsoft365_user)
          .where(
            m365_storage_sources: {
              active: true
            }
          )

        relation = apply_owner_upns(relation)
        relation = apply_excluded_owner_upns(relation)
        relation = apply_scan_status(relation)
        relation = apply_source_type(relation)

        apply_search(relation)
      end
    end

    def aggregated_scope
      filtered_sources_scope
        .left_joins(
          source_items: :drive_item
        )
        .select(select_columns)
        .group(group_columns)
        .reorder(order_clause)
    end

    def apply_search(relation)
      return relation if search.blank?

      escaped_search =
        ActiveRecord::Base.sanitize_sql_like(search)

      relation.where(
        <<~SQL.squish,
          m365_storage_sources.source_name ILIKE :search
          OR users365catalog.display_name ILIKE :search
          OR users365catalog.user_principal_name ILIKE :search
        SQL
        search: "%#{escaped_search}%"
      )
    end

    def apply_scan_status(relation)
      return relation if scan_status.blank?

      relation.where(
        m365_storage_sources: {
          scan_status: scan_status
        }
      )
    end

    def apply_source_type(relation)
      return relation if source_type.blank?

      relation.where(
        m365_storage_sources: {
          source_type: source_type
        }
      )
    end

    def apply_owner_upns(relation)
      return relation if owner_upns.empty?

      relation.where(
        "LOWER(users365catalog.user_principal_name) IN (?)",
        owner_upns
      )
    end

    def apply_excluded_owner_upns(relation)
      return relation if excluded_owner_upns.empty?

      relation.where(
        <<~SQL.squish,
          (
            users365catalog.user_principal_name IS NULL
            OR LOWER(
              users365catalog.user_principal_name
            ) NOT IN (?)
          )
        SQL
        excluded_owner_upns
      )
    end

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

    def compliance_percentage_sql(
      item_type,
      alias_name
    )
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

    def order_clause
  primary_order =
    if direction == "desc"
      sort_expression.desc.nulls_last
    else
      sort_expression.asc.nulls_last
    end

  [
    primary_order,
    Arel.sql(
      "LOWER(m365_storage_sources.source_name)"
    ).asc,
    M365StorageSource.arel_table[:id].asc
  ]
end

def sort_expression
  case sort
  when "name"
    Arel.sql(
      "LOWER(m365_storage_sources.source_name)"
    )

  when "owner"
    Arel.sql(
      <<~SQL.squish
        LOWER(
          COALESCE(
            users365catalog.display_name,
            users365catalog.user_principal_name,
            ''
          )
        )
      SQL
    )

  when "folders_count"
    Arel.sql("folders_count")

  when "folders_compliance"
    Arel.sql("folders_compliance_percentage")

  when "files_count"
    Arel.sql("files_count")

  when "files_compliance"
    Arel.sql("files_compliance_percentage")

  when "pending"
    Arel.sql("pending_items_count")

  when "non_auditable"
    Arel.sql("non_auditable_items_count")

  when "last_evaluated_at"
    Arel.sql("last_evaluated_at")

  else
    raise ArgumentError,
          "Unsupported sort column: #{sort.inspect}"
  end
end

    def offset
      (page - 1) * page_size
    end

    def normalize_filter(value)
      value.to_s.strip.presence
    end

    def normalize_page(value)
      parsed = value.to_i

      parsed.positive? ? parsed : DEFAULT_PAGE
    end

    def normalize_page_size(value)
      parsed = value.to_i
      parsed = DEFAULT_PAGE_SIZE unless parsed.positive?

      [ parsed, MAX_PAGE_SIZE ].min
    end

    def normalize_sort(value)
      normalized = value.to_s
        .strip
        .downcase

      return "files_count" if normalized == "files_desc"

      SORT_COLUMNS.key?(normalized) ?
        normalized :
        DEFAULT_SORT
    end

    def normalize_direction(value, raw_sort:)
      if raw_sort.to_s.strip.downcase == "files_desc"
        return "desc"
      end

      normalized = value.to_s
        .strip
        .downcase

      DIRECTIONS.include?(normalized) ?
        normalized :
        DEFAULT_DIRECTION
    end

    def normalize_owner_upns(value)
      Array(value)
        .filter_map do |upn|
          upn.to_s
            .strip
            .downcase
            .presence
        end
        .uniq
    end

    def quote(value)
      AuditRecord.connection.quote(value)
    end
  end
end
