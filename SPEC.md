# browser-metered-proxy — Project Specification

A minimal, open source Rails API proxy that sits between local-first browser apps and external APIs. It handles the three things a browser app fundamentally cannot do on its own: **keep secrets, receive webhooks, and meter usage for billing.**

The core promise: **every external API call is logged with its raw provider cost and your markup separately, so users always know exactly what they are being charged and why.**

---

## The Problem

Local-first browser apps — especially those built with WebAssembly (Rails, Ruby, etc. running in the browser) — run entirely client-side. This is great for cost and privacy, but creates a structural problem:

| What the app needs | Why the browser can't do it |
|--------------------|-----------------------------|
| Call Plaid, Stripe, OpenAI, etc. | API keys would be visible in the browser |
| Receive webhooks | No persistent server URL to POST to |
| Track usage per user | Can't trust client-side billing records |
| Make server-to-server calls | Some APIs explicitly block browser origins |

The solution is a thin, trusted server-side layer that the browser delegates these specific tasks to — and nothing else.

---

## What This Project Is

A **Rails API-only app** that acts as a secure, metered, capability-based proxy:

```
Browser App (local-first, WASM/SPA)
  │
  │  Authorization: Bearer <jwt>
  │  POST /api/capability { capability, payload }
  ▼
browser-metered-proxy
  ├── Validates JWT → identifies actor
  ├── Validates capability + payload schema
  ├── Executes capability (validate → meter → store → emit)
  ├── Logs: raw provider cost + markup + total charged (always separate)
  └── Returns structured result
        │
        ▼
  External APIs (Plaid, Stripe, OpenAI, SendGrid, etc.)
```

It is intentionally **minimal**. It does not:

- Store application data (that lives in the browser's SQLite)
- Render any UI
- Manage user sessions beyond JWT validation
- Contain business logic that belongs in the browser app
- Chain capabilities together or orchestrate workflows (the browser app owns that)

---

## Core Responsibilities

### 1. Authentication

Every request carries a JWT (`Authorization: Bearer`). The identity ties every capability execution and usage record to a specific actor. Tokens are issued on registration/login.

### 2. Secret Storage

API keys for external services live only here — in environment variables. The browser never sees them.

### 3. Capability Dispatch

Receives a request from the browser, routes it to the named capability, executes it, and returns a structured result. Every capability does exactly one thing: validate → meter → call provider → store → log.

### 4. Transparent Metered Billing

Every capability execution is logged with three cost fields — always:

- `raw_cost_cents` — what the provider actually charged
- `markup_cents` — the proxy operator's markup on top
- `total_charged_cents` — what the actor actually pays

These are never collapsed into a single number. The browser app reads this log to show users a fully transparent billing dashboard.

### 5. Webhook Relay

External services post status updates to this proxy. Webhooks are validated and stored so the browser app can poll for status updates.

### 6. Submission Integrity (Optional)

For capabilities that handle sensitive form submissions (e.g. `submit_application`), the browser can sign the payload with an Ed25519 key. The proxy verifies the signature and stores it alongside the submission — providing cryptographic proof of exactly what was submitted and non-repudiation. This is for **payload integrity**, not identification (JWT handles that).

---

## Capability Model

### What Is a Capability

A capability is the atomic unit of work in this proxy. Every action a browser app delegates to the proxy is a capability. Each capability:

- Has a unique name and version
- Declares its cost upfront (type, base cost, markup)
- Does exactly one thing: validate → meter → call provider → store → log
- Does **not** call other capabilities or trigger workflows
- Does **not** contain business logic about what happens next

### Capability Definition

```ruby
class VerifyIncome < BaseCapability
  DEFINITION = {
    capability: "verify_income",
    version: "1.0",
    provider: "plaid",
    cost: {
      type: "passthrough",
      base_cost_cents: 150,
      markup_percent: 2
    }
  }.freeze

  def call(actor_id:, payload:)
    # validate → call provider → store result → return
  end
end
```

### Cost Types

| Type | Meaning | Use case |
|------|---------|----------|
| `passthrough` | Provider's real cost + markup, shown separately | All Plaid/Stripe/OpenAI calls |
| `fixed` | Fixed credit amount regardless of provider cost | Simple operations |
| `free` | No charge | Auth, status checks, log reads |
| `variable` | Cost depends on payload (e.g. token count) | OpenAI completions, batch ops |

For all `passthrough` capabilities: `base_cost_cents`, `markup_cents`, and `total_charged_cents` are always stored and always returned in the response. This is the core transparency promise of this project.

### Capability Execution Flow

Every capability follows this exact sequence:

```
Step 1: Validate
  → JWT valid? actor identified?
  → capability exists?
  → payload matches schema?
  → (submission capabilities only) Ed25519 signature valid?

Step 2: Call external provider (if applicable)
  → use server-side API key
  → record raw_cost_cents from provider response

Step 3: Meter — log the call
  → write CapabilityLog with all three cost fields
  → this record is immutable once written

Step 4: Store result
  → write to appropriate model (ExternalItem, SubmissionRecord, etc.)
  → regular capabilities: structured JSON
  → submission capabilities: opaque encrypted blob (browser encrypts before sending)

Step 5: Return
  → { capability_log_id, status, result, raw_cost_cents, markup_cents, total_charged_cents }
```

### Submission Capabilities and Ed25519

For capabilities that store sensitive user-submitted data (e.g. `submit_application`), the browser optionally signs the payload before sending:

```json
{
  "capability": "submit_application",
  "payload": { "encrypted_blob": "..." },
  "signature": {
    "algorithm": "ed25519",
    "public_key": "base64...",
    "value": "base64..."
  }
}
```

The proxy verifies the signature and stores it alongside the `SubmissionRecord`. This gives the system a tamper-proof audit trail of exactly what the actor submitted — the actor cannot later claim the submission contained different data. JWT still handles identification; Ed25519 handles payload integrity.

---

## Transparent Billing — The Core Promise

Every capability execution that touches an external provider produces a billing record with three separate cost fields. These are never collapsed.

### CapabilityLog Record

```ruby
CapabilityLog:
  id
  actor_id                  # who invoked it (from JWT)
  capability                # "verify_income", "initiate_transfer", etc.
  version                   # capability version at time of call
  provider                  # "plaid", "stripe", "openai", nil (for free capabilities)
  provider_request_id       # provider's own request ID for cross-referencing

  # Cost fields — always all three, always separate
  raw_cost_cents            # what the provider charged (0 for free/fixed)
  markup_cents              # operator markup
  total_charged_cents       # raw + markup

  charged_to                # "actor" | "end_customer" (pass-through billing)
  metadata_json             # opaque context from browser app (entity IDs, etc.)

  status                    # "success" | "failed"
  error_code                # nil on success
  invoked_at
  completed_at
```

### What the Browser App Displays

```
Date          Capability           Base Cost  Markup   Total
Apr 29        verify_income        $1.50      $0.03    $1.53
Apr 29        submit_application   $0.00      $0.00    $0.00
Apr 28        initiate_transfer    $0.25      $0.003   $0.253
Apr 28        verify_identity      $1.00      $0.02    $1.02
Apr 27        link_session         $0.50      $0.01    $0.51
```

Raw cost, markup, and total are always shown separately. The proxy guarantees this data is available; displaying it is the browser app's responsibility.

---

## Data Models

```ruby
# Every capability execution — billing and audit record
CapabilityLog:
  actor_id, capability, version, provider, provider_request_id
  raw_cost_cents, markup_cents, total_charged_cents
  charged_to, metadata_json, status, error_code
  invoked_at, completed_at

# Encrypted provider credentials (access tokens, etc.)
ExternalItem:
  actor_id
  provider                  # "plaid", "stripe", etc.
  item_type                 # provider-specific type string
  external_id               # provider's own ID
  access_token_encrypted    # encrypted at rest
  metadata_json
  created_at

# Opaque submission storage
SubmissionRecord:
  id, actor_id, capability
  payload                   # encrypted blob or structured JSON
  signature                 # Ed25519 signature (nil if not signed)
  public_key                # actor's public key at time of submission
  status                    # "submitted" | "reviewed" | "accepted" | "rejected"
  idempotency_key
  created_at
```

---

## API

### Single Dispatch Endpoint

```
POST /api/capability
  Authorization: Bearer <jwt>
  Body: { capability, payload, signature? }
  Returns: { capability_log_id, status, result, raw_cost_cents, markup_cents, total_charged_cents }
```

All capability invocations go through this single endpoint. The dispatcher looks up the capability by name and routes execution.

### Auth

```
POST /api/auth/register    → create account, return JWT
POST /api/auth/login       → return JWT
```

### Usage & Billing (read-only)

```
GET  /api/usage/log        → paginated CapabilityLog for this actor
                             filterable by: date range, capability, provider, status
                             always returns raw_cost_cents + markup_cents + total separately

GET  /api/usage/summary    → {
                               this_month_total_cents,
                               this_month_raw_cost_cents,
                               this_month_markup_cents,
                               all_time_total_cents,
                               breakdown_by_capability,
                               breakdown_by_provider,
                               call_count_this_month
                             }
```

### Webhooks (no auth — validated by provider signature)

```
POST /api/webhooks/plaid
POST /api/webhooks/stripe
POST /api/webhooks/:provider
```

---

## File Structure

```
app/
├── capabilities/
│   ├── base_capability.rb        # shared lifecycle: validate → meter → store → log
│   ├── plaid/
│   │   ├── link_session.rb
│   │   ├── exchange_token.rb
│   │   ├── verify_income.rb
│   │   ├── verify_identity.rb
│   │   └── initiate_transfer.rb
│   └── submissions/
│       └── submit_application.rb
│
├── controllers/
│   └── api/
│       ├── capability_controller.rb   # single dispatch endpoint
│       ├── auth_controller.rb
│       ├── usage_controller.rb
│       └── webhooks/
│           ├── plaid_controller.rb
│           └── stripe_controller.rb
│
├── models/
│   ├── capability_log.rb
│   ├── external_item.rb
│   └── submission_record.rb
│
└── services/
    ├── capability_dispatcher.rb    # JWT validation + capability routing
    ├── signature_verifier.rb       # Ed25519 verification for submission capabilities
    └── cost_calculator.rb          # base_cost + markup → total, per cost type

config/
├── capabilities.yml               # capability registry (name → class mapping)
├── providers.yml                  # provider cost config (base costs + markups)
└── workflows.yml                  # (future) event → downstream capability chains
```

---

## Adding a New Integration

1. Create `app/capabilities/[provider]/[name].rb` inheriting from `BaseCapability`
2. Define `DEFINITION` with capability name, version, provider, cost
3. Implement `call(actor_id:, payload:)` — validate, call provider, return result
4. Register in `config/capabilities.yml`
5. Add cost config to `config/providers.yml`
6. Add webhook controller under `api/webhooks/` if the provider requires one

The metering and logging is handled by `BaseCapability` — subclasses never write `CapabilityLog` records directly.

---

## Security Model

### Authentication

JWT Bearer on every request except webhooks. Token contains `actor_id`.

### Submission Integrity (Ed25519)

For submission capabilities only — verifies the payload hasn't been tampered with and provides non-repudiation. The actor cannot later deny submitting specific data.

```ruby
SignatureVerifier.verify!(
  signature: params[:signature][:value],
  public_key: params[:signature][:public_key],
  message: canonical(params[:capability], params[:payload])
)
```

### Observability — No PII in Logs

Application logs record only:
```
capability_log_id, actor_id, capability, status, total_charged_cents, duration_ms
```

Never logged: email addresses, names, phone numbers, application contents, financial details.

---

## Provider Cost Configuration

```yaml
# config/providers.yml

providers:
  plaid:
    link_session:
      base_cost_cents: 50
      markup_percent: 2
    income_verify:
      base_cost_cents: 150
      markup_percent: 2
    identity_verify:
      base_cost_cents: 100
      markup_percent: 2
    ach_transfer:
      base_cost_cents: 25
      markup_percent: 1
    balance_check:
      base_cost_cents: 10
      markup_percent: 1

  openai:
    chat_completion:
      base_cost_cents: 0        # variable — read from API response headers
      markup_percent: 10

  stripe:
    charge:
      base_cost_cents: 0        # Stripe fees deducted from payout
      markup_percent: 0.5
```

---

## How Browser Apps Integrate

1. Register → receive JWT
2. Store JWT in local SQLite (never a cookie)
3. For every external API need, `POST /api/capability` with capability name and payload
4. Store `capability_log_id` from every response in local SQLite for audit trail
5. Call `GET /api/usage/log` and `GET /api/usage/summary` to populate the cost transparency dashboard
6. Display `raw_cost_cents`, `markup_cents`, and `total_charged_cents` separately — never collapse them

---

## Environment Variables

```bash
# Rails
SECRET_KEY_BASE=

# Auth
JWT_SECRET=
JWT_EXPIRY_HOURS=720

# App
APP_NAME=MyApp

# Plaid
PLAID_CLIENT_ID=
PLAID_SECRET=
PLAID_ENV=sandbox

# Stripe
STRIPE_SECRET_KEY=
STRIPE_WEBHOOK_SECRET=

# CORS
FRONTEND_ORIGIN=https://yourapp.pages.dev

# Encryption (access tokens at rest)
ENCRYPTION_KEY=

# Default markup (overridden per provider in config/providers.yml)
DEFAULT_MARKUP_PERCENT=2
```

---

## Deployment

Standard Rails API app — runs anywhere Ruby runs:

- **Fly.io** — scales to zero (~$3–5/mo for low traffic)
- **Render** — free tier available
- **Railway** — simple deploys, good DX
- **Kamal** — zero-downtime deploys to any VPS

A `Dockerfile` is included. Requirements: Ruby 3.3.2, SQLite3.

```bash
bundle install
cp .env.example .env    # fill in secrets
bin/rails db:migrate
bin/rails server
```

---

## Roadmap

- [ ] `BaseCapability` class with shared validate → meter → store → log lifecycle
- [ ] `CapabilityDispatcher` — single `POST /api/capability` routing
- [ ] Auth endpoints (`POST /api/auth/register`, `POST /api/auth/login`)
- [ ] Rename `UsageRecord` → `CapabilityLog` with updated fields
- [ ] `SubmissionRecord` model + Ed25519 signature verification
- [ ] Plaid capabilities ported from current controller actions
- [ ] `config/capabilities.yml` registry
- [ ] Stripe integration capability
- [ ] OpenAI integration capability
- [ ] Webhook relay via polling endpoint or Server-Sent Events
- [ ] Admin dashboard — usage across all actors
- [ ] Client library for browser apps (JS — wraps JWT auth + fetch)
- [ ] Rate limiting per actor per capability
