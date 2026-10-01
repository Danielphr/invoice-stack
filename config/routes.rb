Rails.application.routes.draw do
  root "dashboard#index"

  resource :session
  resource :registration, only: %i[new create]
  resources :passwords, param: :token
  resource :onboarding, only: %i[show update]

  resources :clients
  resources :invoices

  get "up" => "rails/health#show", as: :rails_health_check
end
