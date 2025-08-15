# app/controllers/areas_controller.rb
class AreasController < ApplicationController
  before_action :authenticate_user!
  before_action :set_location
  before_action :set_area, only: [ :edit, :update ]

  def create
    @area = @location.areas.build(area_params)

    if @area.save
      redirect_to location_path(@location), notice: "Area was successfully created."
    else
      @areas = @location.areas
      render "locations/show", status: :unprocessable_entity
    end
  end

  def edit
    # The view will be rendered from app/views/areas/edit.html.erb
  end

  def update
    if @area.update(area_params)
      redirect_to location_path(@location), notice: "Area was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_location
    @location = Location.find(params[:location_id])
  end

  def set_area
    @area = @location.areas.find(params[:id])
  end

  def area_params
    params.require(:area).permit(:name, :export_code, :color)
  end
end
