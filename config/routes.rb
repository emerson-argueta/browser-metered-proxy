Rails.application.routes.draw do
  namespace :api do
    # Auth
    post "auth/register", to: "auth#register"
    post "auth/login",    to: "auth#login"

    # Single capability dispatch
    post "capability", to: "capability#invoke"

    # Usage & billing (read-only)
    get "usage/log",     to: "usage#log"
    get "usage/summary", to: "usage#summary"

    # Webhooks (no auth — validated by provider signature)
    namespace :webhooks do
      post "plaid",     to: "plaid#receive"
      post ":provider", to: "generic#receive"
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
