Rails.application.routes.draw do
  root to: "welcome#index"

  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end

  # Public pages
  get "welcome/index"
  get "dashboards", to: "dashboards#index"
  get "client_dashboard", to: "dashboards#index", defaults: { format: :json }

  # Settings
  get "settings", to: "settings#index", as: :settings

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
      post :contact
      patch :archive
      patch :restore
      delete :remove_attachment
      delete :remove_id_document
    end
  end
  resources :locations do
    resources :areas, only: [ :index, :create, :edit, :update, :destroy ]
    member do
      patch :archive
      patch :restore
      post :send_service_agreement
      post :resend_service_agreement
      delete :remove_attachment
    end
  end
  concern :commentable do
    resources :comments, only: [:index, :create]
  end
  resources :users, concerns: :commentable
  resources :locations, concerns: :commentable
  resources :comments, only: [:edit, :update, :destroy] do
    member do
      delete :remove_file
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
  get "timesheets/open_for_shift/:shift_id", to: "timesheets#open_for_shift", as: :open_timesheet_for_shift

  namespace :admin do
    resources :agreements, only: [ :index, :new, :create, :edit, :update ] do
      collection do
        get :view
      end
    end
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

  # Agreements
  get  "agreements/:document_type", to: "agreements#show",   as: :agreement
  post "agreements/:document_type/accept", to: "agreements#accept", as: :accept_agreement
  get  "agreements/:document_type/download", to: "agreements#download", as: :download_agreement

  # Public service agreement signing (no login)
  get  "service_agreements/:token", to: "service_agreements#show", as: :service_agreement
  get  "service_agreements/:token/download", to: "service_agreements#download", as: :download_service_agreement
  post "service_agreements/:token/accept", to: "service_agreements#accept", as: :accept_service_agreement

  resources :rosters do
    member do
      post :publish
      post :publish_with_email
      post :revert_to_draft
      post :copy_previous_week
      get :compact
      get :day_details
      get :day_pills
    end
    collection do
        get "week(/:date)", to: "rosters#show_by_date", as: "show_by_date"
    end
  end

  # Health check
  get "notifications", to: "notifications#index", as: :notifications
  get "up" => "rails/health#show", as: :rails_health_check
end
