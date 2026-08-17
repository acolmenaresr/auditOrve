class Users365Controller < ApplicationController
  before_action :authorize_events!

  before_action :set_user,
                only: :show


  def index
    query = Users365::CatalogQuery.new(
      search: params[:search],
      department: params[:department],
      job_title: params[:job_title],
      manager_upn: params[:manager_upn],
      license_status: params[:license_status],
      status: params[:status],
      page: params[:page],
      page_size: params[:per_page],
      sort: params[:sort],
      direction: params[:direction]
    )

    @records = query.records

    @departments = query.departments
    @job_titles = query.job_titles
    @managers = query.managers

    @page = query.page
    @per_page = query.page_size

    @total_count = query.total_count
    @total_pages = query.total_pages

    @sort = query.sort
    @direction = query.direction

    @first_record =
      if @total_count.zero?
        0
      else
        (
          (@page - 1) *
          @per_page
        ) + 1
      end

    @last_record =
      [
        @page * @per_page,
        @total_count
      ].min
  end


  def show
    @return_to =
      safe_return_path(
        params[:return_to]
      )

    @date_range = Audit::DateRange.new(
      filter:
        params[:date_filter].presence ||
        "last_30_days",
      custom_from: params[:from],
      custom_to: params[:to]
    )

    query =
      Users365::UserDashboardQuery.new(
        user_principal_name:
          @user.user_principal_name,
        from: @date_range.from,
        to: @date_range.to,
        action: params[:audit_action],
        page: params[:page],
        page_size: params[:per_page],
        sort: params[:sort],
        direction: params[:direction],
        include_discardables:
          params[:include_discardables]
      )

    @records = query.records
    @actions = query.actions

    @page = query.page
    @per_page = query.page_size

    @total_count = query.total_count
    @total_pages = query.total_pages

    @sort = query.sort
    @direction = query.direction

    @include_discardables =
      query.include_discardables

    @top_application =
      query.top_application

    @top_action =
      query.top_action

    @last_movement_at =
      query.last_movement_at

    @unique_files_count =
      query.unique_files_count

    @first_record =
      if @total_count.zero?
        0
      else
        (
          (@page - 1) *
          @per_page
        ) + 1
      end

    @last_record =
      [
        @page * @per_page,
        @total_count
      ].min
  end


  private


  def set_user
    @user =
      Microsoft365User.find(
        params[:id]
      )
  end


  def safe_return_path(value)
    path =
      value
        .to_s
        .strip

    return users365_path if path.blank?

    return users365_path unless path.start_with?(
      "/"
    )

    return users365_path if path.start_with?(
      "//"
    )

    path
  end
end
