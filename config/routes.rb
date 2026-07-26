Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    # Auth
    post "auth/register",        to: "auth#register"
    post "auth/login",           to: "auth#login"
    post "auth/refresh",         to: "auth#refresh"
    post "auth/logout",          to: "auth#logout"
    post "auth/forgot_password", to: "auth#forgot_password"
    post "auth/reset_password",  to: "auth#reset_password"

    # Single capability dispatch
    post "capability",       to: "capability#invoke"
    get  "capability/quote", to: "capability#quote"

    # Usage & billing (read-only)
    get "usage/log",     to: "usage#log"
    get "usage/summary", to: "usage#summary"

    # Webhooks (no auth — validated by provider signature)
    namespace :webhooks do
      post "plaid",   to: "plaid#receive"
      post "stripe",  to: "stripe#receive"
    end
  end
end
