module Users365
  class CatalogQuery
    DEFAULT_PAGE = 1
    DEFAULT_PAGE_SIZE = 25
    MAX_PAGE_SIZE = 100

    DEFAULT_SORT = "display_name"
    DEFAULT_DIRECTION = "asc"

    EMPTY_FILTER_VALUE = "__none__".freeze
    INACTIVE_DAYS = 90

    LICENSE_FILTERS = %w[
      with_license
      without_license
    ].freeze

    STATUS_FILTERS = %w[
      active
      inactive
      without_activity
      disabled
    ].freeze

    SORTABLE_COLUMNS = {
      "display_name" => "display_name",
      "user_principal_name" => "user_principal_name",
      "department" => "department",
      "job_title" => "job_title",
      "manager_name" => "manager_name",
      "last_activity_date" => "last_activity_date",
      "account_enabled" => "account_enabled"
    }.freeze

    DIRECTIONS = %w[asc desc].freeze

    attr_reader :search,
                :department,
                :job_title,
                :manager_upn,
                :license_status,
                :status,
                :page,
                :page_size,
                :sort,
                :direction

    def initialize(
      search: nil,
      department: nil,
      job_title: nil,
      manager_upn: nil,
      license_status: nil,
      status: nil,
      page: DEFAULT_PAGE,
      page_size: DEFAULT_PAGE_SIZE,
      sort: DEFAULT_SORT,
      direction: DEFAULT_DIRECTION
    )
      @search = normalize_filter(search)
      @department = normalize_filter(department)
      @job_title = normalize_filter(job_title)

      @manager_upn =
        normalize_filter(manager_upn)&.downcase

      @license_status = normalize_allowed_filter(
        license_status,
        LICENSE_FILTERS
      )

      @status = normalize_allowed_filter(
        status,
        STATUS_FILTERS
      )

      @page = normalize_page(page)
      @page_size = normalize_page_size(page_size)
      @sort = normalize_sort(sort)
      @direction = normalize_direction(direction)
    end

    def records
      @records ||= filtered_scope
        .order(*order_expression)
        .limit(page_size)
        .offset(offset)
    end

    def total_count
      @total_count ||= filtered_scope.count
    end

    def total_pages
      return 1 if total_count.zero?

      (total_count.to_f / page_size).ceil
    end

    def departments
      @departments ||= Microsoft365User
        .where(
          "NULLIF(BTRIM(department), '') IS NOT NULL"
        )
        .distinct
        .order(
          Arel.sql("BTRIM(department) ASC")
        )
        .pluck(
          Arel.sql("BTRIM(department)")
        )
    end

    def job_titles
      @job_titles ||= Microsoft365User
        .where(
          "NULLIF(BTRIM(job_title), '') IS NOT NULL"
        )
        .distinct
        .order(
          Arel.sql("BTRIM(job_title) ASC")
        )
        .pluck(
          Arel.sql("BTRIM(job_title)")
        )
    end

    def managers
      @managers ||= Microsoft365User
        .where(
          <<~SQL.squish
            NULLIF(BTRIM(manager_upn), '') IS NOT NULL
            AND NULLIF(BTRIM(manager_name), '') IS NOT NULL
          SQL
        )
        .distinct
        .order(
          Arel.sql(
            <<~SQL.squish
              BTRIM(manager_name) ASC,
              LOWER(BTRIM(manager_upn)) ASC
            SQL
          )
        )
        .pluck(
          Arel.sql("BTRIM(manager_name)"),
          Arel.sql("LOWER(BTRIM(manager_upn))")
        )
        .map do |manager_name, manager_upn|
          {
            name: manager_name,
            upn: manager_upn
          }
        end
    end

    private

    def filtered_scope
      scope = Microsoft365User.all

      scope = apply_search(scope)

      scope = apply_nullable_text_filter(
        scope,
        :department,
        department
      )

      scope = apply_nullable_text_filter(
        scope,
        :job_title,
        job_title
      )

      scope = apply_manager_filter(scope)
      scope = apply_license_filter(scope)
      scope = apply_status_filter(scope)

      scope
    end

    def apply_search(scope)
      return scope if search.blank?

      escaped_search =
        ActiveRecord::Base.sanitize_sql_like(search)

      pattern = "%#{escaped_search}%"

      scope.where(
        <<~SQL.squish,
          display_name ILIKE :pattern
          OR user_principal_name ILIKE :pattern
          OR first_name ILIKE :pattern
          OR last_name ILIKE :pattern
        SQL
        pattern:
      )
    end

    def apply_nullable_text_filter(scope, column, value)
      return scope if value.blank?

      quoted_column =
        Microsoft365User.connection.quote_column_name(column)

      if value == EMPTY_FILTER_VALUE
        scope.where(
          "NULLIF(BTRIM(#{quoted_column}), '') IS NULL"
        )
      else
        scope.where(
          "BTRIM(#{quoted_column}) = ?",
          value
        )
      end
    end

    def apply_manager_filter(scope)
      return scope if manager_upn.blank?

      if manager_upn == EMPTY_FILTER_VALUE
        scope.where(
          <<~SQL.squish
            NULLIF(BTRIM(manager_upn), '') IS NULL
            OR NULLIF(BTRIM(manager_name), '') IS NULL
          SQL
        )
      else
        scope.where(
          "LOWER(BTRIM(manager_upn)) = ?",
          manager_upn
        )
      end
    end

    def apply_license_filter(scope)
      case license_status
      when "with_license"
        scope.where(
          "(#{license_count_sql}) >= 1"
        )

      when "without_license"
        scope.where(
          "(#{license_count_sql}) = 0"
        )

      else
        scope
      end
    end

    def apply_status_filter(scope)
      cutoff_date = INACTIVE_DAYS.days.ago.to_date

      case status
      when "disabled"
        scope.where(
          "account_enabled IS NOT TRUE"
        )

      when "without_activity"
        scope
          .where("account_enabled IS TRUE")
          .where(last_activity_date: nil)

      when "inactive"
        scope
          .where("account_enabled IS TRUE")
          .where.not(last_activity_date: nil)
          .where(
            "last_activity_date < ?",
            cutoff_date
          )

      when "active"
        scope
          .where("account_enabled IS TRUE")
          .where(
            "last_activity_date >= ?",
            cutoff_date
          )

      else
        scope
      end
    end

    # Convierte la columna licenses a JSONB para soportar:
    # - jsonb
    # - json
    # - arreglo nativo de PostgreSQL
    #
    # Devuelve 0 cuando el valor es NULL o no es un arreglo.
    def license_count_sql
      @license_count_sql ||= begin
        connection = Microsoft365User.connection

        quoted_table =
          connection.quote_table_name(
            Microsoft365User.table_name
          )

        quoted_column =
          connection.quote_column_name("licenses")

        full_column = "#{quoted_table}.#{quoted_column}"

        <<~SQL.squish
          CASE
            WHEN #{full_column} IS NULL
              THEN 0

            WHEN jsonb_typeof(
              to_jsonb(#{full_column})
            ) = 'array'
              THEN jsonb_array_length(
                to_jsonb(#{full_column})
              )

            ELSE 0
          END
        SQL
      end
    end

    def order_expression
      table = Microsoft365User.arel_table
      column_name = SORTABLE_COLUMNS.fetch(sort)
      column = table[column_name]

      # Prioridad:
      # 0 = usuario con una o más licencias
      # 1 = usuario sin licencia
      license_priority = Arel.sql(
        <<~SQL.squish
          CASE
            WHEN (#{license_count_sql}) >= 1
              THEN 0
            ELSE 1
          END ASC
        SQL
      )

      primary_order =
        if direction == "asc"
          column.asc.nulls_last
        else
          column.desc.nulls_last
        end

      [
        license_priority,
        primary_order,
        table[:id].asc
      ]
    end

    def offset
      (page - 1) * page_size
    end

    def normalize_filter(value)
      value.to_s.strip.presence
    end

    def normalize_allowed_filter(value, allowed_values)
      normalized = normalize_filter(value)

      return if normalized.blank?

      if allowed_values.include?(normalized)
        normalized
      end
    end

    def normalize_page(value)
      parsed = value.to_i

      parsed.positive? ? parsed : DEFAULT_PAGE
    end

    def normalize_page_size(value)
      parsed = value.to_i
      parsed = DEFAULT_PAGE_SIZE unless parsed.positive?

      [parsed, MAX_PAGE_SIZE].min
    end

    def normalize_sort(value)
      normalized = value.to_s

      if SORTABLE_COLUMNS.key?(normalized)
        normalized
      else
        DEFAULT_SORT
      end
    end

    def normalize_direction(value)
      normalized = value.to_s.downcase

      if DIRECTIONS.include?(normalized)
        normalized
      else
        DEFAULT_DIRECTION
      end
    end
  end
end