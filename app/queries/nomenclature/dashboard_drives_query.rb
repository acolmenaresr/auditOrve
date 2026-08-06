module Nomenclature
  class DashboardDrivesQuery
    TOP_LIMIT = 10

    COMMON_OWNER_UPNS = %w[
      grupoorve@grupoorve.mx
      proyectos.cloud@grupoorve.mx
      marketing.cloud@grupoorve.mx
    ].freeze

    def call
      {
        common_drives: common_drives_query.records.to_a,
        top_drives: top_drives_query.records.to_a
      }
    end

    private

    def top_drives_query
      DrivesIndexQuery.new(
        page: 1,
        page_size: TOP_LIMIT,
        sort: :files_desc,
        excluded_owner_upns: excluded_top_owner_upns
      )
    end

    def common_drives_query
      DrivesIndexQuery.new(
        page: 1,
        page_size: 100,
        sort: :name,
        owner_upns: COMMON_OWNER_UPNS
      )
    end

    def excluded_top_owner_upns
      COMMON_OWNER_UPNS +
        Nomenclature::ServiceAccounts::OWNER_UPNS
    end
  end
end
