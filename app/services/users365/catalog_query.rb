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
      department =
        trimmed_column(:department)

      department_present =
        nullable_trimmed_column(:department).not_eq(nil)

      @departments ||= Microsoft365User
        .where(department_present)
        .distinct
        .order(department.asc)
        .pluck(department)
    end

    def job_titles
      job_title =
        trimmed_column(:job_title)

      job_title_present =
        nullable_trimmed_column(:job_title).not_eq(nil)

      @job_titles ||= Microsoft365User
        .where(job_title_present)
        .distinct
        .order(job_title.asc)
        .pluck(job_title)
    end

    def managers
      manager_name =
        trimmed_column(:manager_name)

      manager_upn =
        lower_trimmed_column(:manager_upn)

      manager_name_present =
        nullable_trimmed_column(:manager_name).not_eq(nil)

      manager_upn_present =
        nullable_trimmed_column(:manager_upn).not_eq(nil)

      @managers ||= Microsoft365User
        .where(
          manager_name_present.and(
            manager_upn_present
          )
        )
        .distinct
        .order(
          manager_name.asc,
          manager_upn.asc
        )
        .pluck(
          manager_name,
          manager_upn
        )
        .map do |name, upn|
          {
            name:,
            upn:
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

      trimmed =
        trimmed_column(column)

      nullable_trimmed =
        nullable_trimmed_column(column)

      if value == EMPTY_FILTER_VALUE
        scope.where(
          nullable_trimmed.eq(nil)
        )
      else
        scope.where(
          trimmed.eq(value)
        )
      end
    end

    def apply_manager_filter(scope)
      return scope if manager_upn.blank?

      if manager_upn == EMPTY_FILTER_VALUE
        manager_upn_empty =
          nullable_trimmed_column(:manager_upn).eq(nil)

        manager_name_empty =
          nullable_trimmed_column(:manager_name).eq(nil)

        scope.where(
          manager_upn_empty.or(
            manager_name_empty
          )
        )
      else
        scope.where(
          lower_trimmed_column(:manager_upn).eq(
            manager_upn
          )
        )
      end
    end

    def apply_license_filter(scope)
      case license_status
      when "with_license"
        scope.where(
          license_count_expression.gteq(1)
        )

      when "without_license"
        scope.where(
          license_count_expression.eq(0)
        )

      else
        scope
      end
    end

    def apply_status_filter(scope)
      cutoff_date =
        INACTIVE_DAYS.days.ago.to_date

      case status
      when "disabled"
        scope.where(
          "account_enabled IS NOT TRUE"
        )

      when "without_activity"
        scope
          .where(
            "account_enabled IS TRUE"
          )
          .where(
            last_activity_date: nil
          )

      when "inactive"
        scope
          .where(
            "account_enabled IS TRUE"
          )
          .where.not(
            last_activity_date: nil
          )
          .where(
            "last_activity_date < ?",
            cutoff_date
          )

      when "active"
        scope
          .where(
            "account_enabled IS TRUE"
          )
          .where(
            "last_activity_date >= ?",
            cutoff_date
          )

      else
        scope
      end
    end

    # Calcula el número de licencias directamente en PostgreSQL
    # sin concatenar ni interpolar SQL.
    #
    # Admite que licenses sea JSON, JSONB o un arreglo convertido
    # mediante la función to_jsonb.
    def license_count_expression
      licenses =
        Microsoft365User.arel_table[:licenses]

      licenses_as_json =
        Arel::Nodes::NamedFunction.new(
          "to_jsonb",
          [ licenses ]
        )

      licenses_json_type =
        Arel::Nodes::NamedFunction.new(
          "jsonb_typeof",
          [ licenses_as_json ]
        )

      licenses_array_length =
        Arel::Nodes::NamedFunction.new(
          "jsonb_array_length",
          [ licenses_as_json ]
        )

      Arel::Nodes::Case.new
        .when(
          licenses.eq(nil)
        )
        .then(0)
        .when(
          licenses_json_type.eq("array")
        )
        .then(
          licenses_array_length
        )
        .else(0)
    end

    def order_expression
      table = Microsoft365User.arel_table
      column_name = SORTABLE_COLUMNS.fetch(sort)
      column = table[column_name]

      # 0: usuarios con una o más licencias.
      # 1: usuarios sin licencia.
      license_priority =
        Arel::Nodes::Case.new
          .when(
            license_count_expression.gteq(1)
          )
          .then(0)
          .else(1)
          .asc

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

    def trimmed_column(column)
      Arel::Nodes::NamedFunction.new(
        "BTRIM",
        [
          Microsoft365User.arel_table[column]
        ]
      )
    end

    def nullable_trimmed_column(column)
      Arel::Nodes::NamedFunction.new(
        "NULLIF",
        [
          trimmed_column(column),
          Arel::Nodes.build_quoted("")
        ]
      )
    end

    def lower_trimmed_column(column)
      Arel::Nodes::NamedFunction.new(
        "LOWER",
        [
          trimmed_column(column)
        ]
      )
    end

    def offset
      (page - 1) * page_size
    end

    def normalize_filter(value)
      value.to_s.strip.presence
    end

    def normalize_allowed_filter(
      value,
      allowed_values
    )
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

      unless parsed.positive?
        parsed = DEFAULT_PAGE_SIZE
      end

      [ parsed, MAX_PAGE_SIZE ].min
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
