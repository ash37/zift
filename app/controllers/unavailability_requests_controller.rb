# app/controllers/unavailability_requests_controller.rb
class UnavailabilityRequestsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_unavailability_request, only: %i[ show edit update approve decline destroy ]

  def index
    if current_user.admin? || current_user.manager?
      @unavailability_requests = UnavailabilityRequest.order(starts_at: :desc)
    else
      @unavailability_requests = current_user.unavailability_requests.order(starts_at: :desc)
    end
  end

  def show
  end

  def new
    @unavailability_request = UnavailabilityRequest.new
  end

  def edit
  end

  def create
    @unavailability_request = current_user.unavailability_requests.build(processed_unavailability_params)
    @unavailability_request.status = UnavailabilityRequest::STATUSES[:pending]

    if @unavailability_request.save
      redirect_to unavailability_requests_path, notice: "Unavailability request was successfully submitted."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @unavailability_request.update(processed_unavailability_params)
      redirect_to unavailability_requests_path, notice: "Unavailability request was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @unavailability_request.destroy
    redirect_to unavailability_requests_path, notice: "Unavailability request was successfully deleted."
  end

  def approve
    @unavailability_request.update(status: UnavailabilityRequest::STATUSES[:approved])
    respond_to do |format|
      format.html do
        redirect_to(params[:from] == "notifications" ? notifications_path : unavailability_requests_path, notice: "Request approved.")
      end
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove(view_context.dom_id(@unavailability_request, :row)),
          turbo_stream.replace("pending_unavailability_count", partial: "notifications/badge")
        ]
      end
    end
  end

  def decline
    @unavailability_request.update(status: UnavailabilityRequest::STATUSES[:declined])
    respond_to do |format|
      format.html do
        redirect_to(params[:from] == "notifications" ? notifications_path : unavailability_requests_path, notice: "Request declined.")
      end
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove(view_context.dom_id(@unavailability_request, :row)),
          turbo_stream.replace("pending_unavailability_count", partial: "notifications/badge")
        ]
      end
    end
  end

  private

  def set_unavailability_request
    @unavailability_request = UnavailabilityRequest.find(params[:id])
  end

  def unavailability_request_params
    params.require(:unavailability_request).permit(:reason, :starts_at, :ends_at, :starts_at_time, :ends_at_time, :all_day, :repeats_weekly)
  end

  def processed_unavailability_params
    attrs = unavailability_request_params.to_h

    start_date_str = attrs[:starts_at]
    end_date_str   = attrs[:ends_at].presence || start_date_str
    start_time_str = attrs[:starts_at_time]
    end_time_str   = attrs[:ends_at_time].presence || start_time_str

    if attrs[:all_day] == "true"
      # All day: use full-day bounds. Require a start date; end date defaults to start date.
      if start_date_str.present?
        attrs[:starts_at] = Time.zone.parse(start_date_str).beginning_of_day
        if end_date_str.present?
          attrs[:ends_at] = Time.zone.parse(end_date_str).end_of_day
        end
      end
    else
      # Timed: compose from date + time. End date defaults to start date; end time defaults to start time.
      if start_date_str.present? && start_time_str.present?
        attrs[:starts_at] = Time.zone.parse("#{start_date_str} #{start_time_str}")
      end
      if end_date_str.present? && end_time_str.present?
        attrs[:ends_at] = Time.zone.parse("#{end_date_str} #{end_time_str}")
      end
    end

    attrs.except(:starts_at_time, :ends_at_time, :all_day)
  end
end
