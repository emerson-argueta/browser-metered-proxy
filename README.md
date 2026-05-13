# browser-metered-proxy

A minimal Rails API proxy that sits between local-first browser apps and external APIs. It handles the three things a browser app fundamentally cannot do on its own: **keep secrets, receive webhooks, and meter usage for billing.**

Built for WASM/Service Worker apps and SPAs that run entirely client-side but need to call external services like Plaid, Stripe, or OpenAI without exposing API keys.

The core promise: every proxied call is logged with `raw_cost_cents`, `markup_cents`, and `total_charged_cents` always separate — so users always know exactly what they are being charged and why.

## How it works

```
Browser App
  │  Authorization: Bearer <jwt>
  │  POST /api/capability { capability, payload, signature? }
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
  "status": "success",
  "raw_cost_cents": 150,
  "markup_cents": 3,
  "total_charged_cents": 153,
  "income_data": { ... }
}
```

### Plaid — reference implementation

Plaid is included as a reference implementation. It demonstrates the full capability pattern — passthrough billing, encrypted token storage, webhook handling, and free status checks — so adding your own provider is a matter of following the same structure.

| Capability | Cost type | Description |
|---|---|---|
| `link_session` | passthrough | Create a Plaid Link token |
| `exchange_token` | free | Exchange public token, store access token encrypted |
| `verify_income` | passthrough | Income verification |
| `initiate_transfer` | passthrough | ACH transfer |
| `transfer_status` | free | Check transfer status |

### SendGrid — email notifications

| Capability | Cost type | Description |
|---|---|---|
| `send_email` | fixed | Send a transactional email or dynamic template |

Supports plain HTML body or SendGrid dynamic templates via `template_id` + `template_data`. The browser app decides when to send — the proxy just holds the API key and fires the call.

```json
{
  "capability": "send_email",
  "payload": {
    "to": "applicant@example.com",
    "subject": "Your application was accepted",
    "body": "<p>Congratulations...</p>"
  }
}
```

Or with a SendGrid dynamic template:

```json
{
  "capability": "send_email",
  "payload": {
    "to": "applicant@example.com",
    "template_id": "d-abc123",
    "template_data": { "first_name": "Jane", "property": "123 Oak St" }
  }
}
```

### Form submissions — signed payload storage

| Capability | Cost type | Description |
|---|---|---|
| `submit_form` | free | Store a form submission with optional Ed25519 signature |

For sensitive submissions where you need a tamper-proof audit trail (e.g. a rental application, a contract acceptance), the browser can sign the payload before sending. The proxy verifies the signature and stores it alongside the submission — giving you cryptographic proof of exactly what was submitted.

**Without signature** (basic storage):
```json
{
  "capability": "submit_form",
  "payload": {
    "data": { "name": "Jane Doe", "income": 75000 },
    "idempotency_key": "application_123"
  }
}
```

**With Ed25519 signature** (tamper-proof):
```json
{
  "capability": "submit_form",
  "payload": {
    "data": { "name": "Jane Doe", "income": 75000 },
    "idempotency_key": "application_123"
  },
  "signature": {
    "algorithm": "ed25519",
    "public_key": "<base64-encoded public key>",
    "value": "<base64-encoded signature>"
  }
}
```

The signature covers the canonical form of `capability + payload`, so neither can be altered after signing. `idempotency_key` prevents duplicate submissions — a second request with the same key returns the original record.

To add Stripe, OpenAI, or any other provider: follow the same pattern in `app/capabilities/[provider]/`.

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

### Deploying with Kamal (`bin/deploy`)

The `bin/deploy` script wraps Kamal with secret loading and multi-app support.

**First-time setup:**
```bash
bin/deploy setup
```

**Deploy:**
```bash
bin/deploy
```

**Multi-app deployments:**

Each app gets its own deploy config file:
```
config/
  deploy.yml                # default app (e.g. budget-clear)
  deploy.my-other-app.yml   # second app
  deploy.app3.yml           # third app
```

Use the `-c` flag to target a specific app:
```bash
bin/deploy -c my-other-app          # deploy my-other-app
bin/deploy setup -c my-other-app    # first-time setup for my-other-app
```

Multiple apps run as separate Docker containers on the same server, each with their own SQLite volume and environment variables.

### Credit management

Grant free credits to users without requiring payment:

```bash
# Grant $10 to a user
bin/deploy credits:grant EMAIL=friend@example.com AMOUNT=10

# List all actors and balances
bin/deploy credits:list

# Check one user's balance
bin/deploy credits:balance EMAIL=friend@example.com

# Set balance to a specific amount (overwrites)
bin/deploy credits:set EMAIL=friend@example.com AMOUNT=25
```

With `-c` for a specific app:
```bash
bin/deploy credits:grant -c my-other-app EMAIL=friend@example.com AMOUNT=10
```

### Environment variables

| Variable | Description |
|----------|-------------|
| `MAX_TOPUP_CENTS` | Maximum top-up per transaction in cents (default: `5000` = $50) |
| `REQUIRE_PAYMENT` | Set to `true` to enforce Stripe payment for credits |
| `PLAID_ENV` | `sandbox` \| `development` \| `production` |
| `FRONTEND_ORIGIN` | Comma-separated allowed CORS origins |
