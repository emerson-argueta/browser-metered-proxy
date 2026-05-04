# browser-metered-proxy

A minimal Rails API proxy that sits between local-first browser apps and external APIs. It handles the three things a browser app fundamentally cannot do on its own: **keep secrets, receive webhooks, and meter usage for billing.**

Built for use with WASM/Service Worker apps (and any SPA) that run entirely client-side but need to call external services like Plaid, Stripe, or OpenAI without exposing API keys.

## How it works

```
Browser App
  │  Authorization: Bearer <jwt>
  ▼
browser-metered-proxy
  ├── Validates JWT → identifies the user
  ├── Calls external API with server-side credentials
  ├── Logs the call: cost + markup + context
  └── Returns result to browser
        ▼
  External APIs (Plaid, Stripe, OpenAI, etc.)
```

## API

```
POST   /api/auth/register              create account, return JWT
POST   /api/auth/login                 return JWT

GET    /api/usage/log                  paginated call log for the current user
GET    /api/usage/summary              monthly totals and breakdown by call type

POST   /api/plaid/link_token           create a Plaid Link token
POST   /api/plaid/exchange_token       exchange public token, store access token
POST   /api/plaid/income/verify        income verification
POST   /api/plaid/transfer/initiate    initiate an ACH transfer
GET    /api/plaid/transfer/status/:id  transfer status
POST   /api/plaid/webhooks             receive Plaid webhooks (no auth)
```

## Setup

**Requirements:** Ruby 3.3.2, SQLite3

```bash
bundle install
cp .env.example .env   # fill in your secrets
bin/rails db:migrate
bin/rails server
```

## Environment variables

```bash
# Rails
SECRET_KEY_BASE=

# Auth
JWT_SECRET=
JWT_EXPIRY_HOURS=720        # 30 days default

# App
APP_NAME=MyApp              # used as the client_name in Plaid Link

# Plaid
PLAID_CLIENT_ID=
PLAID_SECRET=
PLAID_ENV=sandbox           # sandbox | development | production

# CORS — set to your browser app's origin
FRONTEND_ORIGIN=https://yourapp.pages.dev

# Encryption key for access tokens stored at rest
ENCRYPTION_KEY=
```

## Adding a new integration

1. Create `app/controllers/api/[provider]_controller.rb`
2. Add routes under `namespace :api`
3. Use `log_usage` to record every proxied call
4. Store access tokens via `ExternalItem`
5. Add a webhook endpoint if the provider requires one

## Deployment

Standard Rails API app — deploy anywhere that runs Ruby. Recommended options for low-traffic / scale-to-zero:

- [Fly.io](https://fly.io) (~$3–5/mo)
- [Render](https://render.com)
- [Railway](https://railway.app)

A `Dockerfile` is included.
