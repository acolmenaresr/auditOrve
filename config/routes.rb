Rails.application.routes.draw do
  root "dashboard#index"

  # Autenticación
  get "login", to: "sessions#new", as: :login
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout
  get "/reset-password", to: "password_resets#edit", as: :reset_password
  patch "/reset-password", to: "password_resets#update", as: :update_password

  # Aplicación
  get "dashboard", to: "dashboard#index", as: :dashboard
  get "auditoria", to: "audit_logs#index", as: :audit_logs
  get "usuarios-365", to: "users365#index", as: :users365
  get "usuarios-365/:id", to: "users365#show", as: :user365
  resources :audit_users, path: "usuarios", only: %i[new create]

  # Cloud Orve
  get "cloudorve", to: "nomenclature_audits#index", as: :cloudorve
  get "cloudorve/drives", to: "nomenclature_audits#drives", as: :cloudorve_drives
  get "cloudorve/drives/:id/children", to: "nomenclature_audits#children", as: :cloudorve_drive_children
  get "cloudorve/drives/:id", to: "nomenclature_audits#show", as: :cloudorve_drive

  # Estado de la aplicación
  get "up" => "rails/health#show", as: :rails_health_check
end
