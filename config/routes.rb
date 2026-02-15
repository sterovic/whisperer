Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Devise routes for user authentication
  devise_for :users, controllers: {
    sessions: "users/sessions"
  }

  # GoodJob dashboard - protect this in production with authentication
  mount GoodJob::Engine => "good_job"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Dashboard
  get "dashboard", to: "dashboard#index", as: :dashboard

  # Jobs management
  resources :jobs, only: [:index] do
    collection do
      post :trigger
    end
  end

  # Job schedules management
  resources :job_schedules, only: [:update] do
    member do
      post :toggle
      post :run_now
    end
  end

  # Videos management
  resources :videos, only: [:index, :show, :destroy] do
    collection do
      get :import
      post :import, action: :create_import
      post :bulk_post_comments
      post :bulk_search_related
    end
    member do
      get :comment_frequency
    end
  end

  # Video search
  resources :video_searches, only: [:index, :create] do
    collection do
      get :autocomplete
      post :search_related
    end
  end

  # Google Accounts (YouTube OAuth)
  resources :google_accounts, only: [:index] do
    member do
      patch :disconnect
    end
    collection do
      get :authorize
      get :oauth_callback
    end
  end

  # Comments management
  resources :comments, only: [:index] do
    member do
      get :reply_form
      post :reply
      post :upvote
    end
  end

  # SMM Panels
  namespace :smm_panels do
    resources :jap, only: [:index] do
      collection do
        patch :index, action: :update
        post :test_connection
        get :services
      end
    end
  end

  # SMM Orders (all panels)
  resources :smm_orders, only: [:index]

  # Channels
  resources :channels, only: [:index]
  namespace :channels do
    resources :subscriptions, only: [:index, :new, :create, :destroy]
  end

  # Settings namespace
  namespace :settings do
    resource :project, only: [:show, :update], controller: "project"
  end

  # Prompt settings (project-level AI configuration)
  resource :prompt_settings, only: [:show, :update] do
    post :test
  end

  # Projects management
  resources :projects do
    member do
      post :switch
    end
  end

  # Defines the root path route ("/")
  root "dashboard#index"
end
