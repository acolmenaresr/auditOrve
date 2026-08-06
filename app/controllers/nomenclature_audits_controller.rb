class NomenclatureAuditsController < ApplicationController
  before_action :set_drive, only: %i[
    show
    children
  ]

  def index
    @overview = Nomenclature::OverviewQuery.new.call

    dashboard_drives =
      Nomenclature::DashboardDrivesQuery.new.call

    @common_drives =
      dashboard_drives.fetch(:common_drives)

    @top_drives =
      dashboard_drives.fetch(:top_drives)
  end

  def drives
    query = Nomenclature::DrivesIndexQuery.new(
      search: params[:search],
      scan_status: params[:scan_status],
      source_type: params[:source_type],
      page: params[:page],
      page_size: params[:per_page],
      sort: params[:sort],
      direction: params[:direction],
      excluded_owner_upns:
        Nomenclature::ServiceAccounts::OWNER_UPNS
    )

    redirect_out_of_range_page(query) and return

    @drives = query.records

    @search = query.search
    @scan_status = query.scan_status
    @source_type = query.source_type
    @sort = query.sort
    @direction = query.direction

    @page = query.page
    @per_page = query.page_size
    @total_count = query.total_count
    @total_pages = query.total_pages

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

    @scan_status_options =
      eligible_sources_scope
        .where.not(scan_status: [ nil, "" ])
        .distinct
        .order(:scan_status)
        .pluck(:scan_status)

    @source_type_options =
      eligible_sources_scope
        .where.not(source_type: [ nil, "" ])
        .distinct
        .order(:source_type)
        .pluck(:source_type)
  end

  def show
    @return_to =
      safe_return_path(params[:return_to])

    @drive_summary =
      Nomenclature::DrivesIndexQuery.new(
        scope: M365StorageSource.where(
          id: @drive.id
        ),
        page: 1,
        page_size: 1
      ).records.first

    raise ActiveRecord::RecordNotFound unless @drive_summary

    @tree_items =
      Nomenclature::DriveTreeChildrenQuery.new(
        source: @drive
      ).call.to_a
  end

  def children
    parent_item_id =
      params[:parent_item_id]
        .to_s
        .strip

    raise ActiveRecord::RecordNotFound if parent_item_id.blank?

    @parent_item =
      M365SourceItem
        .joins(:drive_item)
        .where(
          source_id: @drive.id,
          is_deleted: false,
          m365_drive_items: {
            item_id: parent_item_id,
            item_type: "folder",
            is_deleted: false
          }
        )
        .select(
          "m365_source_items.id",
          "m365_source_items.drive_item_id",
          "m365_drive_items.item_id"
        )
        .take!

    @tree_items =
      Nomenclature::DriveTreeChildrenQuery.new(
        source: @drive,
        parent_item_id: parent_item_id
      ).call.to_a
  end

  private

  def set_drive
    @drive =
      eligible_sources_scope
        .preload(:microsoft365_user)
        .find(params[:id])
  end

  def eligible_sources_scope
    M365StorageSource
      .left_joins(:microsoft365_user)
      .where(active: true)
      .where(
        <<~SQL.squish,
          (
            users365catalog.user_principal_name IS NULL
            OR LOWER(
              users365catalog.user_principal_name
            ) NOT IN (?)
          )
        SQL
        Nomenclature::ServiceAccounts::OWNER_UPNS
      )
  end

  def safe_return_path(value)
    path = value.to_s.strip

    return cloudorve_drives_path if path.blank?
    return cloudorve_drives_path unless path.start_with?("/")
    return cloudorve_drives_path if path.start_with?("//")

    path
  end

  def redirect_out_of_range_page(query)
    return false if query.total_count.zero?
    return false if query.page <= query.total_pages

    redirect_to cloudorve_drives_path(
      search: query.search,
      scan_status: query.scan_status,
      source_type: query.source_type,
      sort: query.sort,
      direction: query.direction,
      per_page: query.page_size,
      page: query.total_pages
    )

    true
  end
end
