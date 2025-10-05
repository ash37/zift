class IncidentsController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    @incidents = Incident.order(created_at: :desc)
  end

  def show
    @incident = Incident.find(params[:id])
  end

  def new
    @incident = Incident.new
  end

  def create
    @incident = Incident.new(incident_params)

    if @incident.save
      IncidentMailer.notify_admin(@incident).deliver_later
      redirect_to success_incidents_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def success; end

  private

  def incident_params
    params.require(:incident).permit(
      :reporter_first_name,
      :reporter_last_name,
      :reporter_email,
      :category,
      :details,
      :incident_date,
      :incident_time,
      :incident_address_line1,
      :incident_suburb,
      :incident_state,
      :incident_postcode,
      :witnesses,
      :immediate_action,
      :police_notified,
      :client_first_name,
      :client_last_name,
      :client_behaviour,
      :injuries_sustained,
      :treatment_required,
      :property_damage
    )
  end
end
