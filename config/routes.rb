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
    end
    member do
      get :comment_frequency
    end
  end

  # Google Accounts (YouTube OAuth)
  resources :google_accounts, only: [:index, :destroy] do
    collection do
      get :authorize
      get :oauth_callback
    end
  end

  # Comments management
  resources :comments, only: [:index]

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
