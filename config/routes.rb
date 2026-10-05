Rails.application.routes.draw do
  root "dashboard#index"

  resource :session
  resource :registration, only: %i[new create]
  resources :passwords, param: :token
  resource :onboarding, only: %i[show update]

  resource :company, only: %i[ show edit update ] do
    resource :logo, only: :destroy, module: :companies
  end
  resource :settings, only: %i[ show update ]
  resource :account, only: :show
  namespace :account do
    resource :profile, only: :update
    resource :password, only: :update
  end
  resources :clients do
    resource :archive, only: %i[ create destroy ], module: :clients
  end
  resources :invoices do
    resource :status, only: :update, module: :invoices
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
