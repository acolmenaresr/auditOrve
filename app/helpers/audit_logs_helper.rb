module AuditLogsHelper
  def sortable_audit_header(label, column)
    active = @sort == column
    next_direction =
      active && @direction == "asc" ? "desc" : "asc"

    icon =
      if active
        @direction == "asc" ? "▲" : "▼"
      else
        "↕"
      end

    preserved_params =
      request.query_parameters.except(
        "page",
        "sort",
        "direction"
      )

    link_to(
      audit_logs_path(
        preserved_params.merge(
          sort: column,
          direction: next_direction,
          page: 1
        )
      ),
      class: [
        "audit-sort-link",
        ("is-active" if active)
      ].compact.join(" ")
    ) do
      safe_join(
        [
          content_tag(:span, label),
          content_tag(
            :span,
            icon,
            class: "audit-sort-link__icon",
            aria: { hidden: true }
          )
        ],
        " "
      )
    end
  end
end