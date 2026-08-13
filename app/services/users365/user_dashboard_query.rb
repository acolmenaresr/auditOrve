module Users365
  class UserDashboardQuery
    DEFAULT_PAGE = 1
    DEFAULT_PAGE_SIZE = 25
    MAX_PAGE_SIZE = 100

    DEFAULT_SORT = "dateZ"
    DEFAULT_DIRECTION = "desc"

    # Conservamos las keys que ya envía la UI.
    SORTABLE_COLUMNS = {
      "dateZ" => "occurred_at",
      "accion" => "movement_code",
      "operacion365" => "operation",
      "aplicacion" => "application",
      "tipoItem" => "item_type",
      "archivo" => "file_name",
      "ruta" => "path",
      "sitio" => "site_url"
    }.freeze

    DIRECTIONS = %w[asc desc].freeze

    attr_reader :user_principal_name,
                :from,
                :to,
                :action,
                :page,
                :page_size,
                :sort,
                :direction

    def initialize(
      user_principal_name:,
      from:,
      to:,
      action: nil,
      page: DEFAULT_PAGE,
      page_size: DEFAULT_PAGE_SIZE,
      sort: DEFAULT_SORT,
      direction: DEFAULT_DIRECTION
    )
      @user_principal_name =
        normalize_filter(user_principal_name)&.downcase

      @from = from
      @to = to
      @page = normalize_page(page)
      @page_size = normalize_page_size(page_size)
      @sort = normalize_sort(sort)
      @direction = normalize_direction(direction)
      @action = normalize_filter(action)
    end

    def actions
      @actions ||= user_scope
        .where.not(movement_code: [nil, ""])
        .distinct
        .order(:movement_code)
        .pluck(:movement_code)
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

    def top_application
      @top_application ||= ranked_value(
        <<~SQL.squish
          COALESCE(
            NULLIF(BTRIM("application"), ''),
            'Sin aplicación'
          )
        SQL
      )
    end

    def top_action
      @top_action ||= ranked_value(
        <<~SQL.squish
          COALESCE(
            NULLIF(BTRIM("movement_code"), ''),
            'Sin acción'
          )
        SQL
      )
    end

    def last_movement_at
      @last_movement_at ||=
        filtered_scope.maximum(:occurred_at)
    end

    def unique_files_count
      @unique_files_count ||= filtered_scope
        .where.not(resource_key: [nil, ""])
        .distinct
        .count(:resource_key)
    end

    private

    def base_scope
      return AuditMovement.none if user_principal_name.blank?

      date_column =
        AuditMovement.arel_table[:occurred_at]

      AuditMovement.where(
        date_column
          .gteq(from.beginning_of_day)
          .and(
            date_column.lt(to.beginning_of_day)
          )
      )
    end

    def user_scope
      @user_scope ||= base_scope.where(
        <<~SQL.squish,
          LOWER(
            BTRIM(
              COALESCE("user_name", '')
            )
          ) = ?
        SQL
        user_principal_name
      )
    end

    def filtered_scope
      scope = user_scope

      scope = scope.where(
        movement_code: action
      ) if action.present?

      scope
    end

    def ranked_value(label_expression)
      row = filtered_scope
        .group(
          Arel.sql(label_expression)
        )
        .order(
          Arel.sql("COUNT(*) DESC")
        )
        .limit(1)
        .pluck(
          Arel.sql(label_expression),
          Arel.sql("COUNT(*)")
        )
        .first

      return {
        label: "Sin información",
        events: 0
      } unless row

      {
        label: row[0],
        events: row[1].to_i
      }
    end

    def order_expression
      table = AuditMovement.arel_table

      column_name =
        SORTABLE_COLUMNS.fetch(sort)

      column =
        table[column_name]

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

      unless parsed.positive?
        parsed = DEFAULT_PAGE_SIZE
      end

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
      normalized =
        value.to_s.downcase

      if DIRECTIONS.include?(normalized)
        normalized
      else
        DEFAULT_DIRECTION
      end
    end
  end
end
