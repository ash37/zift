class Admin::ShiftTypesController < ApplicationController
  before_action :authenticate_user!
  # before_action :require_admin!

  def index
    @shift_types = ShiftType.all.order(:name)
    @xero_earnings_rates = ShiftType.where.not(xero_earnings_rate_id: nil).order(:name)
    @new_shift_type = ShiftType.new # For the "Add New" form
  end

  def create
    @shift_type = ShiftType.new(shift_type_params)
    if @shift_type.save
      redirect_to admin_shift_types_path, notice: "Shift type was successfully created."
    else
      # If create fails, re-render the index page with the errors
      @shift_types = ShiftType.all.order(:name)
      @xero_earnings_rates = ShiftType.where.not(xero_earnings_rate_id: nil).order(:name)
      @new_shift_type = @shift_type # Keep the object with errors for the form
      render :index, status: :unprocessable_entity
    end
  end

  def update
    @shift_type = ShiftType.find(params[:id])
    if @shift_type.update(shift_type_params)
      redirect_to admin_shift_types_path, notice: "Shift type mapping was successfully updated."
    else
      render :index, status: :unprocessable_entity
    end
  end

  private

  def shift_type_params
    # Permit :name for create, and :xero_earnings_rate_id for update
    params.require(:shift_type).permit(:name, :xero_earnings_rate_id)
  end
end
