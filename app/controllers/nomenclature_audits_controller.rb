class NomenclatureAuditsController < ApplicationController
  def index
    @overview = Nomenclature::OverviewQuery.new.call
    @drives = Nomenclature::DrivesIndexQuery.new.call.limit(10)
  end
end