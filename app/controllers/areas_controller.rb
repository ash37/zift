# app/controllers/areas_controller.rb
class AreasController < ApplicationController
  before_action :set_location

  def create
    @area = @location.areas.build(area_params)

    if @area.save
      redirect_to location_path(@location), notice: 'Area was successfully created.'
    else
      @areas = @location.areas
      render 'locations/show', status: :unprocessable_entity
    end
  end

  private

  def set_location
    @location = Location.find(params[:location_id])
  end

  def area_params
    params.require(:area).permit(:name, :export_code, :color)
  end
end
