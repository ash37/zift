Rails.application.routes.draw do
  root to: "welcome#index"

  # Public pages
  get "welcome/index"
  get "dashboards", to: "dashboards#index"

  resources :applications, only: [ :new, :create ] do
    get "success", on: :collection
  end

  # Devise authentication
  devise_for :users, controllers: { registrations: "users/registrations" }

  devise_scope :user do
    get "users/invitation/accept", to: "users/registrations#edit", as: "accept_user_invitation"
  end

  # Admin-managed user creation
  get  "users/new",    to: "users#new",    as: :admin_new_user
  post "users/create", to: "users#create", as: :admin_create_user

  # Core resources
  resources :users, except: [ :new, :create ] do
    member do
      post :employ
    end
  end
  resources :locations do
    # THE FIX IS HERE: Added edit and update to the areas resource
    resources :areas, only: [ :create, :edit, :update ]
    member do
      patch :archive
      patch :restore
    end
  end
  resources :shifts
  resources :shift_questions
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
      # Add these lines for the new unscheduled timesheet feature
      get "new_unscheduled", to: "timesheets#new_unscheduled", as: :new_unscheduled
      post "create_unscheduled", to: "timesheets#create_unscheduled", as: :create_unscheduled
    end
  end

  namespace :admin do
    resource :xero_connection, only: [ :show, :new, :create, :destroy, :update ] do
      get :callback, on: :collection
      get :edit_user_mappings, on: :collection
      patch :update_user_mappings, on: :collection
    end
    resources :shift_types, only: [ :index, :update, :create ]
    resources :xero_timesheet_exports, only: [ :index, :new, :create ]
    resources :xero_invoice_exports, only: [ :new, :create ]
    resource :xero_item_mappings, only: [ :show, :update ] do
      post :sync, on: :collection
    end
    resources :xero_items, only: [] do
      collection do
        post :sync
      end
    end
  end

  resources :unavailability_requests do
    member do
      patch :approve
      patch :decline
    end
  end

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
