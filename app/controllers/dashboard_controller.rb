class DashboardController < ApplicationController
  def index
    @date_range = Audit::DateRange.new(
      filter: params[:period],
      custom_from: params[:from],
      custom_to: params[:to]
    )

    @top_limit = normalized_top_limit

    dashboard = Audit::DashboardQuery.new(
      from: @date_range.from,
      to: @date_range.to,
      limit: @top_limit
    ).call

    @metrics = dashboard[:metrics]
    @top_users = attach_user_profiles(dashboard[:top_users])
    @top_actions = dashboard[:top_actions]
    @top_applications = dashboard[:top_applications]
  end

  private

  def attach_user_profiles(rows)
    normalized_emails = rows.filter_map do |row|
      row[:label].to_s.strip.downcase.presence
    end.uniq

    return rows if normalized_emails.empty?

    users_by_email = Microsoft365User
      .where(
        "LOWER(BTRIM(user_principal_name)) IN (?)",
        normalized_emails
      )
      .index_by do |user|
        user.user_principal_name.to_s.strip.downcase
      end

    rows.map do |row|
      normalized_email = row[:label].to_s.strip.downcase

      row.merge(
        directory_user: users_by_email[normalized_email]
      )
    end
  end

  def normalized_top_limit
    value = Integer(params[:top], exception: false)

    [10, 15, 20].include?(value) ? value : 10
  end
end