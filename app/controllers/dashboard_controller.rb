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
    @top_users = dashboard[:top_users]
    @top_actions = dashboard[:top_actions]
    @top_applications = dashboard[:top_applications]
  end


  private

  def normalized_top_limit
    value = Integer(params[:top], exception: false)

    [ 10, 15, 20 ].include?(value) ? value : 10
  end
end
