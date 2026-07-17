class AuditLogsController < ApplicationController
  def index
    @date_range = Audit::DateRange.new(
      filter: params[:date_filter],
      custom_from: params[:from],
      custom_to: params[:to]
    )

    query = Audit::LogsQuery.new(
      from: @date_range.from,
      to: @date_range.to,
      user: params[:user],
      action: params[:audit_action],
      page: params[:page],
      page_size: params[:per_page],
      sort: params[:sort],
      direction: params[:direction]
    )

    @records = query.records
    @users = query.users
    @actions = query.actions
    @page = query.page
    @per_page = query.page_size
    @total_count = query.total_count
    @total_pages = query.total_pages
    @sort = query.sort
    @direction = query.direction
  end
end
