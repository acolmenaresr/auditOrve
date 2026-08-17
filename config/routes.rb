Rails.application.routes.draw do
  # =========================================================
  # HOME
  #
  # Root ya no pertenece a Eventos.
  # HomeController decide el destino según permisos.
  # =========================================================

  root "home#index"


  # =========================================================
  # AUTENTICACIÓN
  # =========================================================

  get "login", to: "sessions#new", as: :login
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout
  # =========================================================
  # RECUPERACIÓN DE CONTRASEÑA
  # =========================================================
  get "/forgot-password", to: "password_recovery_requests#new",
  as: :forgot_password
  post "/forgot-password", to: "password_recovery_requests#create"
  # =========================================================
  # RESTABLECER CONTRASEÑA CON TOKEN
  # =========================================================
  get "/reset-password", to: "password_resets#edit", as: :reset_password
  patch "/reset-password", to: "password_resets#update", as: :update_password

  # =========================================================
  # EVENTOS
  # =========================================================

  get "dashboard", to: "dashboard#index", as: :dashboard
  get "auditoria", to: "audit_logs#index", as: :audit_logs
  get "usuarios-365", to: "users365#index", as: :users365
  get "usuarios-365/:id", to: "users365#show", as: :user365

  # =========================================================
  # USUARIOS ADMINISTRATIVOS
  # =========================================================

  resources :audit_users, path: "usuarios", only: %i[new create]


  # =========================================================
  # CLOUD ORVE
  # =========================================================

  get "cloudorve", to: "nomenclature_audits#index", as: :cloudorve
  get "cloudorve/drives", to: "nomenclature_audits#drives", as: :cloudorve_drives
  get "cloudorve/drives/:id/children", to: "nomenclature_audits#children", as: :cloudorve_drive_children
  get "cloudorve/drives/:id", to: "nomenclature_audits#show", as: :cloudorve_drive

  # =========================================================
  # ESTADO DE LA APLICACIÓN
  # =========================================================

  get "up" => "rails/health#show", as: :rails_health_check
end
