Rails.application.routes.draw do
  root "dashboard#index"

  resource :session
  resources :passwords, param: :token

  get "up" => "rails/health#show", as: :rails_health_check
end
