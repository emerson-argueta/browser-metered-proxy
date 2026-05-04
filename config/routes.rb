Rails.application.routes.draw do
  namespace :api do
    # Plaid endpoints
    post "plaid/link_token"
    post "plaid/exchange_token"
    post "plaid/income/verify", to: "plaid#income_verify"
    post "plaid/transfer/initiate", to: "plaid#transfer_initiate"
    get  "plaid/transfer/status/:transfer_id", to: "plaid#transfer_status"
    post "plaid/webhooks"

    # Usage / billing
    get  "usage/log",     to: "usage#log"
    get  "usage/summary", to: "usage#summary"
    post "billing/usage", to: "usage#record"
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
