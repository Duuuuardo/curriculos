Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "jobs#index"

  resources :jobs, only: %i[index show create update destroy] do
    member do
      post :duplicate
      patch :ignore_keyword
      patch :reset_overrides
      post "ai/generate/:kind", to: "ai#generate", as: :ai_generate, constraints: { kind: /summary|cover_letter/ }
      post "ai/match", to: "ai#match", as: :ai_match
      post "ai/adapt", to: "ai#adapt", as: :ai_adapt
    end
  end

  get "ai/status", to: "ai#status"
  get "ai/models", to: "ai#models"
  post "ai/test", to: "ai#test"
  post "ai/extract_job", to: "ai#extract_job"

  scope :profile, controller: :profiles do
    get ":language", action: :edit, as: :profile
    put ":language", action: :update
    post ":language/copy", action: :copy, as: :copy_profile
    post ":language/import", action: :import, as: :import_profile
  end

  resource :assistant, only: %i[show create destroy], controller: :assistant

  resource :settings, only: %i[edit update], controller: :settings

  resource :backup, only: %i[show create], controller: :backups do
    post :sample
  end
end
