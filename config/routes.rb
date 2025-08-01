Rails.application.routes.draw do
  root to: "welcome#index"

  # Public pages
  get "welcome/index"
  get "dashboards", to: "dashboards#index"

  # Devise authentication
  devise_for :users

  # Core resources
  resources :users
  resources :locations
  resources :shifts
  resources :recurrences
  resources :timesheets
  resources :unavailability_requests
  resources :rosters

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # PWA (optional, uncomment if needed)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end

