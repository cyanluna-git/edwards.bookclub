Rails.application.routes.draw do
  root "home#show"
  get "/reports", to: "reports#show", as: :reports
  post "/reports/docx", to: "reports#generate_docx", as: :reports_docx
  post "/reports/outlook-draft", to: "reports#create_outlook_draft", as: :reports_outlook_draft
  resources :books, only: [:index]
  resources :meetings, only: %i[index show new create edit update]

  get "/sign-in", to: "sessions#new", as: :new_session
  post "/sign-in", to: "sessions#create", as: :session
  get "/auth/sso", to: "sessions#sso", as: :sso_session
  match "/auth/sso/callback", to: "sessions#sso", via: %i[get post], as: :sso_callback
  delete "/sign-out", to: "sessions#destroy", as: :destroy_session
  get "/book-requests/:book_request_id/links/:kind", to: "book_request_links#show", as: :book_request_link

  # Entra ID OIDC SSO — OmniAuth middleware handles POST /auth/entra_id (redirect to Microsoft)
  get "/auth/entra_id/callback", to: "auth/callbacks#entra_id", as: :auth_entra_id_callback
  get "/auth/failure",           to: "auth/callbacks#failure",  as: :auth_failure

  namespace :admin do
    get "/", to: "dashboard#show", as: :dashboard

    resources :members do
      resource :access, controller: "member_accesses", only: %i[create update destroy]

      member do
        patch :deactivate
        patch :reactivate
      end
    end

    resources :meetings do
      resources :attendances, controller: "meeting_attendances", only: %i[create update destroy]
      resources :photos, controller: "meeting_photos", only: %i[create update destroy]
    end

    resources :book_requests
    resources :fiscal_periods
    resources :reserve_policies
  end

  scope module: "member_portal", path: "member", as: "member" do
    get "/", to: "dashboard#show", as: :root
    resources :book_requests, only: %i[index show new create edit update destroy]
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
