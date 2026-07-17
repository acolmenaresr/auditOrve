module Audit
  class LogsQuery
    DEFAULT_PAGE = 1
    DEFAULT_PAGE_SIZE = 10
    MAX_PAGE_SIZE = 100

    DEFAULT_SORT = "datez"
    DEFAULT_DIRECTION = "desc"

    SORTABLE_COLUMNS = {
      "datez" => '"datez"',
      "usuario" => '"usuario"',
      "tipoUsuario" => '"tipoUsuario"',
      "accion" => '"accion"',
      "operacion365" => '"operacion365"',
      "aplicacion" => '"aplicacion"',
      "tipoItem" => '"tipoItem"',
      "archivo" => '"archivo"',
      "ruta" => '"ruta"',
      "sitio" => '"sitio"'
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
        .where.not(usuario: [ nil, "" ])
        .distinct
        .order(:usuario)
        .pluck(:usuario)
    end

    def actions
      @actions ||= actions_scope
        .where.not(accion: [ nil, "" ])
        .distinct
        .order(:accion)
        .pluck(:accion)
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
      AuditLog.where(
        '"datez" >= ? AND "datez" < ?',
        from.beginning_of_day,
        to.beginning_of_day
      )
    end

    def filtered_scope
      scope = base_scope
      scope = scope.where(usuario: user) if user.present?
      scope = scope.where(accion: action) if action.present?
      scope
    end

    def users_scope
      scope = base_scope
      scope = scope.where(accion: action) if action.present?
      scope
    end

    def actions_scope
      scope = base_scope
      scope = scope.where(usuario: user) if user.present?
      scope
    end

def order_expression
  table = AuditLog.arel_table
  column_name = SORTABLE_COLUMNS.fetch(sort).to_sym
  column = table[column_name]

  primary_order =
    if direction.to_s.downcase == "asc"
      column.asc.nulls_last
    else
      column.desc.nulls_last
    end

  [
    primary_order,
    table[:id].desc
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
      value = value.to_s

      SORTABLE_COLUMNS.key?(value) ? value : DEFAULT_SORT
    end

    def normalize_direction(value)
      value = value.to_s.downcase

      DIRECTIONS.include?(value) ? value : DEFAULT_DIRECTION
    end
  end
end
