# browser-metered-proxy

A minimal Rails API proxy that sits between local-first browser apps and external APIs. It handles the three things a browser app fundamentally cannot do on its own: **keep secrets, receive webhooks, and meter usage for billing.**

Built for WASM/Service Worker apps and SPAs that run entirely client-side but need to call external services like Plaid, Stripe, or OpenAI without exposing API keys.

The core promise: every proxied call is logged with `raw_cost_cents`, `markup_cents`, and `total_charged_cents` always separate — so users always know exactly what they are being charged and why.

## How it works

```
Browser App
  │  Authorization: Bearer <jwt>
  │  POST /api/capability { capability, payload }
  ▼
browser-metered-proxy
  ├── Validates JWT → identifies actor
  ├── Dispatches to named capability class
  ├── Calls external API with server-side credentials
  ├── Logs: raw cost + markup + total (always separate)
  └── Returns structured result
        ▼
  External APIs (Plaid, Stripe, OpenAI, etc.)
```

## API

```
POST  /api/auth/register        create account, return JWT
POST  /api/auth/login           return JWT

POST  /api/capability           dispatch any capability (see below)

GET   /api/usage/log            paginated CapabilityLog for the current actor
                                filterable by: capability, provider, status, date range
GET   /api/usage/summary        monthly totals broken down by capability and provider

POST  /api/webhooks/plaid       receive Plaid webhooks (no auth)
POST  /api/webhooks/stripe      receive Stripe webhooks (no auth)
```

### Dispatching a capability

All external API calls go through a single endpoint:

```bash
POST /api/capability
Authorization: Bearer <jwt>

{
  "capability": "verify_income",
  "payload": {
    "external_id": "item_abc123"
  }
}
```

Response always includes cost fields:

```json
{
  "capability_log_id": 42,
  "status": "success",
  "raw_cost_cents": 150,
  "markup_cents": 3,
  "total_charged_cents": 153,
  "income_data": { ... }
}
```

### Built-in capabilities

| Capability | Provider | Description |
|---|---|---|
| `link_session` | Plaid | Create a Plaid Link token |
| `exchange_token` | Plaid | Exchange public token, store access token |
| `verify_income` | Plaid | Income verification |
| `initiate_transfer` | Plaid | ACH transfer |

## Setup

**Requirements:** Ruby 3.3.2, SQLite3

```bash
bundle install
cp .env.example .env   # fill in your secrets
bin/rails db:migrate
bin/rails server
```

## Environment variables

See `.env.example` for the full list. Key ones:

```bash
JWT_SECRET=          # generate with: rails secret
ENCRYPTION_KEY=      # 32+ chars, encrypts stored access tokens
PLAID_CLIENT_ID=
PLAID_SECRET=
PLAID_ENV=sandbox    # sandbox | development | production
FRONTEND_ORIGIN=     # your browser app's origin, for CORS
```

## Adding a new capability

1. Create `app/capabilities/[provider]/[name].rb` inheriting from `BaseCapability`
2. Define `DEFINITION` with capability name, version, provider, and cost type
3. Implement `call` — validate payload, call provider, return result hash
4. Register in `config/capabilities.yml`
5. Add cost config to `config/providers.yml`
6. Add a webhook controller under `app/controllers/api/webhooks/` if needed

Cost logging is handled automatically by `BaseCapability` — capability classes never write `CapabilityLog` records directly.

## Cost configuration

Edit `config/providers.yml` to set base costs and markup per capability:

```yaml
providers:
  plaid:
    verify_income:
      base_cost_cents: 150
      markup_percent: 2
```

## Deployment

Standard Rails API app — runs anywhere Ruby runs:

- [Fly.io](https://fly.io) — scales to zero (~$3–5/mo)
- [Render](https://render.com) — free tier available
- [Railway](https://railway.app) — simple deploys
- [Kamal](https://kamal-deploy.org) — deploy to any VPS

A `Dockerfile` is included.
