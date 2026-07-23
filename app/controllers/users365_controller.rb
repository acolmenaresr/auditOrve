class Users365Controller < ApplicationController
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
        ((@page - 1) * @per_page) + 1
      end

    @last_record = [
      @page * @per_page,
      @total_count
    ].min
  end
end