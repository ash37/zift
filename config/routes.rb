Rails.application.routes.draw do
  root to: "welcome#index"

  # Public pages
  get "welcome/index"
  get "dashboards", to: "dashboards#index"
  resources :applications, only: [ :new, :create ]

  resources :applications, only: [ :new, :create ] do
    get "success", on: :collection
  end

  # Devise authentication - now with custom registrations controller
  devise_for :users, controllers: { registrations: "users/registrations" }

  # Allow self-registration and onboarding
  devise_scope :user do
    # This is the special link from the email
    get "users/invitation/accept", to: "users/registrations#edit", as: "accept_user_invitation"
  end

  # Admin-managed user creation (separate from Devise)
  get  "users/new",    to: "users#new",    as: :admin_new_user
  post "users/create", to: "users#create", as: :admin_create_user

  # Core resources
  resources :users, except: [ :new, :create ] do
    member do
      post :employ
    end
  end
  resources :locations do
    resources :areas, only: [ :create ]
  end
  resources :shifts
  resources :recurrences
  resources :reports, only: [ :index ]

  post "shifts/:id/clock_on", to: "timesheets#clock_on", as: "clock_on_shift"

  resources :timesheets do
    member do
      patch :approve
      get :clock_off_form
      patch :clock_off
      patch :match_roster_times
    end
    collection do
      get "week(/:date)", to: "timesheets#index", as: "week"
    end
  end
  resources :unavailability_requests do
    member do
      patch :approve
      patch :decline
    end
  end
  resources :unavailability_requests

  resources :rosters do
    member do
      post :publish
      post :publish_with_email
      post :revert_to_draft
      post :copy_previous_week
    end
    collection do
        get "week(/:date)", to: "rosters#show_by_date", as: "show_by_date"
    end
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
