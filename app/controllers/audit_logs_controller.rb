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
      include_discardables: params[:include_discardables],
      direction: params[:direction]
    )

    @records = query.records
    @directory_users_by_email = directory_users_by_email(@records)

    @users = query.users
    @actions = query.actions
    @page = query.page
    @per_page = query.page_size
    @total_count = query.total_count
    @total_pages = query.total_pages
    @sort = query.sort
    @direction = query.direction
    @include_discardables = query.include_discardables
  end

  private

  def directory_users_by_email(records)
    normalized_emails = records.filter_map do |record|
      record["usuario"]
        .to_s
        .strip
        .downcase
        .presence
    end.uniq

    return {} if normalized_emails.empty?

    Microsoft365User
      .where(
        "LOWER(BTRIM(user_principal_name)) IN (?)",
        normalized_emails
      )
      .index_by do |user|
        user.user_principal_name.to_s.strip.downcase
      end
  end
end
