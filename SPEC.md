# browser-metered-proxy — Project Specification

A minimal, open source Rails API proxy that sits between local-first browser apps and external APIs. It handles the three things a browser app fundamentally cannot do on its own: **keep secrets, receive webhooks, and meter usage for billing.**

---

## The Problem

Local-first browser apps — especially those built with WebAssembly (Rails, Ruby, etc. running in a Service Worker) — run entirely client-side. This is great for cost and privacy, but creates a structural problem:

| What the app needs | Why the browser can't do it |
|--------------------|-----------------------------|
| Call Plaid, Stripe, OpenAI, etc. | API keys would be visible in the browser |
| Receive webhooks | No persistent server URL to POST to |
| Track usage per user | Can't trust client-side billing records |
| Make server-to-server calls | Some APIs explicitly block browser origins |

The solution is a thin, trusted server-side layer that the browser delegates these specific tasks to — and nothing else.

---

## What This Project Is

A **Rails API-only app** that acts as a secure, metered proxy:

```
Browser App (local-first)
  │
  │  Authorization: Bearer <jwt>
  ▼
browser-metered-proxy
  ├── Validates JWT → knows who the user is
  ├── Calls external API with server-side credentials
  ├── Logs the call: cost + markup + context
  └── Returns result to browser
        │
        ▼
  External APIs (Plaid, Stripe, OpenAI, SendGrid, etc.)
```

It is intentionally **minimal**. It does not:
- Store application data (that lives in the browser's SQLite)
- Render any UI
- Manage user sessions beyond JWT validation
- Duplicate business logic that belongs in the browser app

---

## Core Responsibilities

### 1. Authentication
Every request (except webhooks) requires a JWT in the `Authorization: Bearer` header. The token encodes a `user_id` that ties every API call and usage record to a specific account.

### 2. Secret Storage
API keys for external services (Plaid, Stripe, etc.) live only here — in environment variables. The browser never sees them.

### 3. API Proxying
Receives a request from the browser, calls the appropriate external API using server-side credentials, and returns the result. Each integration lives in its own controller under `api/`.

### 4. Webhook Handling
External services need a real HTTPS URL to POST status updates to. This proxy receives them, validates them, and can relay updates to connected browser clients.

### 5. Metered Usage Tracking
Every proxied API call is logged with:
- Who made it (`user_id`)
- What it was (`call_type`)
- What it cost (`raw_cost_cents` — the provider's actual charge)
- What markup was applied (`markup_cents`)
- What was charged (`total_charged_cents`)
- Context (which entity in the browser app triggered it)

This gives the browser app a full audit log and billing summary via `GET /api/usage/log` and `GET /api/usage/summary`.

---

## Architecture

### Data Models

```ruby
# Tracks every proxied API call for billing and audit
UsageRecord:
  user_id             # who made the call
  call_type           # e.g. "link_session", "ach_transfer", "chat_completion"
  provider            # e.g. "plaid", "openai", "stripe"
  external_request_id # provider's request ID for cross-referencing
  raw_cost_cents      # provider's actual charge
  markup_cents        # our markup on top
  total_charged_cents # raw + markup
  charged_to          # "user" or "end_customer" (user can pass cost through)
  status              # "success" | "failed"
  called_at
  metadata_json       # flexible context (entity IDs from the browser app, etc.)

# Stores encrypted access tokens / API state for external services
ExternalItem:
  user_id
  provider            # "plaid", "stripe", etc.
  item_type           # provider-specific (e.g. "bank_account", "customer")
  external_id         # provider's ID
  access_token_encrypted
  metadata_json
  created_at
```

### API Endpoints

```
# Auth
POST   /api/auth/register     → create account, return JWT
POST   /api/auth/login        → return JWT

# Usage & Billing (read-only for browser app)
GET    /api/usage/log         → paginated call log for this user
GET    /api/usage/summary     → monthly/all-time totals + breakdown by call type

# Plaid (current integration)
POST   /api/plaid/link_token          → create Plaid Link token
POST   /api/plaid/exchange_token      → exchange public token → store access token
POST   /api/plaid/income/verify       → income verification
POST   /api/plaid/transfer/initiate   → ACH transfer
GET    /api/plaid/transfer/status/:id → transfer status
POST   /api/plaid/webhooks            → receive Plaid webhooks (no auth)

# [Future integrations follow the same pattern]
# POST /api/openai/chat
# POST /api/stripe/charge
# POST /api/sendgrid/send
```

### Auth Model

JWT-based. Every token contains `user_id`. Tokens are issued on registration/login and have a configurable expiry. No server-side session storage — the proxy is stateless except for the database.

### Cost Model

Each call type has a configurable `base_cost` (what the provider charges) and `markup_rate` (what we add). These are stored in config, not hardcoded, so operators can adjust them.

```
total_charged = base_cost + (base_cost * markup_rate)
```

The browser app can pass costs through to its own end customers (e.g. a landlord charging a tenant for an income verification). The `charged_to` field tracks this.

---

## Adding a New External API Integration

1. Create `app/controllers/api/[provider]_controller.rb`
2. Add routes under `namespace :api`
3. Register cost config in `config/providers.yml` (to be implemented)
4. Use the `log_usage` helper to record every call
5. Store any access tokens via `ExternalItem`
6. Add a webhook endpoint if the provider needs one

The goal is that adding Stripe, OpenAI, or any other provider is a single controller + config, with billing tracking handled automatically.

---

## How Browser Apps Integrate

1. User registers → proxy returns a JWT
2. Browser app stores JWT in local SQLite (never a cookie — app is local-first)
3. Every call that needs an external API goes through the proxy with `Authorization: Bearer <jwt>`
4. Browser app calls `GET /api/usage/summary` to populate its billing dashboard
5. Browser app calls `GET /api/usage/log` for the full audit log

The browser app never knows the provider's API keys. It only knows the results.

---

## Environment Variables

```bash
# Rails
RAILS_ENV=production
SECRET_KEY_BASE=

# Auth
JWT_SECRET=
JWT_EXPIRY_HOURS=720   # 30 days default

# Plaid
PLAID_CLIENT_ID=
PLAID_SECRET=
PLAID_ENV=sandbox      # sandbox | development | production

# CORS — set to your browser app's origin
FRONTEND_ORIGIN=https://yourapp.pages.dev

# Encryption key for access tokens at rest
ENCRYPTION_KEY=
```

---

## Deployment

This is a standard Rails API app. It can be deployed anywhere that runs Ruby:

- **Fly.io** — scales to zero, cheap for low traffic (~$3–5/mo)
- **Render** — free tier available, simple deploys
- **Railway** — straightforward, good DX
- **Heroku** — classic choice, slightly more expensive

A `Dockerfile` is included for containerized deployment.

---

## What Makes This Different from a BFF (Backend for Frontend)

A traditional BFF couples tightly to one frontend app. This proxy is **decoupled** — it has no knowledge of the browser app's data model. It only knows:
- Who is making calls (JWT identity)
- What external service they're calling
- How much it costs

Any browser app that needs to proxy external API calls can point at it. The browser app provides entity IDs (property_id, tenant_id, etc.) as opaque context that gets stored in `metadata_json` — the proxy doesn't understand them, it just logs them.

---

## Roadmap

- [ ] User registration + login endpoints (currently JWT is issued externally)
- [ ] Configurable provider cost table via `config/providers.yml`
- [ ] Webhook relay to browser clients via Server-Sent Events or polling endpoint
- [ ] Stripe integration for collecting payment from users
- [ ] OpenAI integration (chat completions, embeddings)
- [ ] SendGrid integration (transactional email)
- [ ] Rate limiting per user
- [ ] Admin dashboard (usage across all users)
- [ ] Generalize `ExternalItem` → `ProviderCredential` with encryption abstraction
- [ ] SDK / client library for browser apps to call the proxy

