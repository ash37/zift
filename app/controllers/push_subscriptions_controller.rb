class PushSubscriptionsController < ApplicationController
  before_action :authenticate_user!

  def create
    sub = params.require(:subscription).permit(:endpoint, keys: [:p256dh, :auth])
    endpoint = sub[:endpoint]
    keys = sub[:keys] || {}

    ps = PushSubscription.find_or_initialize_by(endpoint: endpoint)
    ps.user = current_user
    ps.p256dh = keys[:p256dh]
    ps.auth = keys[:auth]
    ps.active = true
    ps.user_agent = request.user_agent
    ps.platform = params[:platform]
    ps.last_used_at = Time.current
    if ps.save
      render json: { id: ps.id }, status: :created
    else
      render json: { error: ps.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  def destroy
    ps = current_user.push_subscriptions.find(params[:id])
    ps.update(active: false)
    head :no_content
  end
end

