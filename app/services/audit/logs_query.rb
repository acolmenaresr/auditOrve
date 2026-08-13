module Audit
  class LogsQuery
    DEFAULT_PAGE = 1
    DEFAULT_PAGE_SIZE = 10
    MAX_PAGE_SIZE = 100

    DEFAULT_SORT = "dateZ"
    DEFAULT_DIRECTION = "desc"

    # Conservamos las keys que actualmente usa la UI,
    # pero las dirigimos a las columnas de mv_audit_movements.
    SORTABLE_COLUMNS = {
      "dateZ" => "occurred_at",
      "usuario" => "user_name",
      "tipoUsuario" => "user_type",
      "accion" => "movement_code",
      "operacion365" => "operation",
      "aplicacion" => "application",
      "tipoItem" => "item_type",
      "archivo" => "file_name",
      "ruta" => "path",
      "sitio" => "site_url"
    }.freeze

    DIRECTIONS = %w[asc desc].freeze

    attr_reader :from,
                :to,
                :user,
                :action,
                :page,
                :page_size,
                :sort,
                :direction

    def initialize(
      from:,
      to:,
      user: nil,
      action: nil,
      page: DEFAULT_PAGE,
      page_size: DEFAULT_PAGE_SIZE,
      sort: DEFAULT_SORT,
      direction: DEFAULT_DIRECTION
    )
      @from = from
      @to = to
      @user = normalize_filter(user)
      @action = normalize_filter(action)
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

    def users
      @users ||= users_scope
        .where.not(user_name: [ nil, "" ])
        .distinct
        .order(:user_name)
        .pluck(:user_name)
    end

    def actions
      @actions ||= actions_scope
        .where.not(movement_code: [ nil, "" ])
        .distinct
        .order(:movement_code)
        .pluck(:movement_code)
    end

    def total_count
      @total_count ||= filtered_scope.count
    end

    def total_pages
      return 1 if total_count.zero?

      (total_count.to_f / page_size).ceil
    end

    private

    def base_scope
      date_column = AuditMovement.arel_table["occurred_at"]

      AuditMovement.where(
        date_column
          .gteq(from.beginning_of_day)
          .and(date_column.lt(to.beginning_of_day))
      )
    end

    def filtered_scope
      scope = base_scope
      scope = scope.where(user_name: user) if user.present?
      scope = scope.where(movement_code: action) if action.present?
      scope
    end

    def users_scope
      scope = base_scope
      scope = scope.where(movement_code: action) if action.present?
      scope
    end

    def actions_scope
      scope = base_scope
      scope = scope.where(user_name: user) if user.present?
      scope
    end

    def order_expression
      table = AuditMovement.arel_table
      column_name = SORTABLE_COLUMNS.fetch(sort)
      column = table[column_name]

      primary_order =
        if direction == "asc"
          column.asc.nulls_last
        else
          column.desc.nulls_last
        end

      [
        primary_order,
        table[:movement_id].desc
      ]
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
      normalized_value = value.to_s

      SORTABLE_COLUMNS.key?(normalized_value) ? normalized_value : DEFAULT_SORT
    end

    def normalize_direction(value)
      normalized_value = value.to_s.downcase

      DIRECTIONS.include?(normalized_value) ? normalized_value : DEFAULT_DIRECTION
    end
  end
end
