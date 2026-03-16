Rails.application.routes.draw do
  root "home#show"

  get "/sign-in", to: "sessions#new", as: :new_session
  post "/sign-in", to: "sessions#create", as: :session
  delete "/sign-out", to: "sessions#destroy", as: :destroy_session

  namespace :admin do
    get "/", to: "dashboard#show", as: :dashboard

    resources :members do
      member do
        patch :deactivate
        patch :reactivate
      end
    end

    resources :meetings do
      resources :attendances, controller: "meeting_attendances", only: %i[create update destroy]
      resources :photos, controller: "meeting_photos", only: %i[create update destroy]
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
