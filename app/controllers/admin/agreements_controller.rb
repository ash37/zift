class Admin::AgreementsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_agreement, only: [:edit, :update]

  def index
    @agreements = Agreement.order(document_type: :asc, version: :desc)
    @users = User.with_archived.order(:name).limit(200)
    @locations = Location.order(:name).limit(200)
  end

  def new
    @agreement = Agreement.new(document_type: params[:document_type] || 'employment', version: 1, active: true)
  end

  def create
    @agreement = Agreement.new(agreement_params)
    if @agreement.save
      redirect_to admin_agreements_path, notice: 'Agreement created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @agreement.update(agreement_params)
      redirect_to admin_agreements_path, notice: 'Agreement updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # GET /admin/agreements/view
  # Redirect helper to open an agreement as a chosen user (and optional location)
  def view
    doc = params[:document_type].presence || 'employment'
    user_id = params[:user_id].presence
    location_id = params[:location_id].presence

    redirect_to agreement_path(doc, user_id: user_id, location_id: location_id)
  end

  private
  def set_agreement
    @agreement = Agreement.find(params[:id])
  end

  def require_admin!
    unless current_user&.admin?
      redirect_to root_path, alert: 'Unauthorized'
    end
  end

  def agreement_params
    params.require(:agreement).permit(:document_type, :version, :title, :body, :active)
  end
end
