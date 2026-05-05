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
  │  { actor_id, capability, payload, signature }
  ▼
browser-metered-proxy
  ├── Validates signature + timestamp
  ├── Checks credit balance
  ├── Executes capability (validate → meter → store → emit)
  ├── Logs: raw provider cost + markup + total charged (always separate)
  └── Emits event → workflow engine → downstream capabilities
        │
        ▼
  External APIs (Plaid, Stripe, OpenAI, SendGrid, etc.)
```

It is intentionally **minimal**. It does not:

- Store application data (that lives in the browser's SQLite)
- Render any UI
- Manage user sessions beyond JWT/signature validation
- Contain business logic that belongs in the browser app
- Bundle multiple concerns into a single operation

---

## Core Responsibilities

### 1. Authentication

Every request carries either a JWT (`Authorization: Bearer`) or a signed envelope (Ed25519). The identity ties every capability execution and usage record to a specific actor.

### 2. Secret Storage

API keys for external services live only here — in environment variables. The browser never sees them.

### 3. Capability Dispatch

Receives a signed envelope from the browser, routes it to the named capability, executes it, and returns a structured result. Every capability does exactly one thing: validate, meter, store, emit.

### 4. Transparent Metered Billing

Every capability execution is logged with three cost fields — always:

- `raw_cost_cents` — what the provider actually charged (e.g. Plaid's fee)
- `markup_cents` — the proxy operator's markup on top
- `total_charged_cents` — what the actor actually pays

These are never collapsed into a single number. The browser app reads this log to show users a fully transparent billing dashboard.

### 5. Webhook Relay

External services post status updates to this proxy. Webhooks are validated, mapped to the relevant capability log entry, and relayed to the browser app via polling or Server-Sent Events.

### 6. Event Bus & Workflow Engine

After a capability succeeds it emits a structured event. The workflow engine maps events to downstream capability chains — enabling multi-step workflows without coupling capabilities to each other.

---

## Capability Model

### What Is a Capability

A capability is the atomic unit of work in this proxy. Every action a browser app delegates to the proxy is a capability. Each capability:

- Has a unique name and version
- Declares its cost upfront (type, base cost, markup)
- Does exactly one thing: validate → meter → store → emit
- Does **not** call other capabilities directly
- Does **not** send emails, trigger payments, or perform side effects beyond emitting an event

### Capability Definition Schema

```json
{
  "capability": "verify_income",
  "version": "1.0",
  "description": "Verify tenant income via Plaid Income product",
  "provider": "plaid",
  "cost": {
    "type": "passthrough",
    "base_cost_cents": 150,
    "markup_percent": 2,
    "markup_cents": 3,
    "total_cents": 153
  }
}
```

### Cost Types

| Type | Meaning | Use case |
|------|---------|----------|
| `passthrough` | Provider's real cost + markup, shown separately | All Plaid/Stripe calls |
| `fixed` | Fixed credit amount regardless of provider cost | Simple operations |
| `free` | No charge | Auth, status checks, log reads |
| `variable` | Cost depends on payload (e.g. per attachment) | Document storage, batch ops |

**For all `passthrough` capabilities:** `base_cost_cents`, `markup_cents`, and `total_charged_cents` are always stored and always returned in the response. This is non-negotiable — it is the core transparency promise of this project.

### The Signed Envelope

All capability requests use a signed envelope:

```json
{
  "actor_id": "ed25519_public_key_or_jwt_user_id",
  "timestamp": 1710000000,
  "capability": "verify_income",
  "payload": {},
  "signature": "base64_ed25519_signature"
}
```

**Replay protection:** reject if timestamp is older than ±5 minutes, or if signature hash has already been processed (idempotency table).

**Signature verification:**
```
verify(signature, canonical(actor_id + timestamp + capability + payload))
```

### Capability Execution Flow

Every capability follows this exact sequence — no exceptions:

```
Step 1: Validate envelope
  → signature valid?
  → timestamp within window?
  → capability exists?
  → payload matches schema?

Step 2: Check credit balance
  → actor has sufficient credits for capability cost?
  → fail with insufficient_funds if not

Step 3: Call external provider (if applicable)
  → use server-side API key
  → record raw_cost_cents from provider response

Step 4: Meter — deduct credits + log the call
  → deduct from actor's credit balance
  → write CapabilityLog record with all three cost fields
  → this record is immutable once written

Step 5: Store result
  → write to appropriate model (ExternalItem, SubmissionRecord, etc.)
  → mode A: structured JSON
  → mode B: opaque encrypted blob (recommended for sensitive payloads)

Step 6: Emit event
  → { event: "income.verified", actor_id: ..., submission_id: ..., ... }
  → workflow engine picks up from here
```

---

## Workflow Engine

### What Workflows Are

Workflows are declarative chains of capabilities triggered by events. They are how multi-step business processes are composed without coupling individual capabilities to each other.

A capability never calls another capability. It only emits an event. The workflow engine maps events to the next capability to invoke.

### Workflow Configuration

```yaml
# config/workflows.yml

workflows:

  application.submitted:
    - capability: notify_landlord
    - capability: queue_screening     # only if auto_screening_enabled in metadata

  income.verified:
    - capability: update_application_status

  identity.verified:
    - capability: update_application_status

  transfer.initiated:
    - capability: poll_transfer_status

  transfer.completed:
    - capability: update_payment_record
    - capability: generate_receipt
    - capability: notify_tenant

  transfer.failed:
    - capability: notify_landlord
    - capability: notify_tenant
```

### Workflow Execution Rules

- Workflows execute asynchronously (via Active Job)
- Each downstream capability runs independently — one failure does not block others
- Every workflow execution is logged in `WorkflowLog`
- Workflows are configuration, not code — adding a new downstream step is a one-line change to `workflows.yml`

---

## Transparent Billing — The Core Promise

This is the primary reason this project exists. Every capability execution that touches an external provider produces a billing record with three separate cost fields. These are never collapsed.

### CapabilityLog Record

```ruby
CapabilityLog:
  id
  actor_id                  # who invoked it
  capability                # "verify_income", "initiate_transfer", etc.
  version                   # capability version at time of call
  provider                  # "plaid", "stripe", "openai", nil (for free capabilities)
  provider_request_id       # provider's own request ID for cross-referencing
  
  # Cost fields — always all three, always separate
  raw_cost_cents            # what the provider charged (0 for free/fixed capabilities)
  markup_cents              # operator markup
  total_charged_cents       # raw + markup — what actor was actually charged
  
  charged_to                # "actor" | "end_customer" (pass-through billing)
  
  # Context — opaque IDs from the browser app, not interpreted by the proxy
  metadata_json             # { property_id, tenant_id, listing_id, ... }
  
  status                    # "success" | "failed"
  error_code                # nil on success
  invoked_at
  completed_at
```

### What the Browser App Displays

The browser app calls `GET /api/usage/log` and `GET /api/usage/summary` to build its cost transparency dashboard. The log always has enough information to show:

```
Date          Capability           For                Base Cost  Markup  Total
Apr 29        verify_income        John Smith (app)   $1.50      $0.03   $1.53
Apr 29        submit_application   123 Oak St         $0.00      $0.00   $0.00
Apr 28        initiate_transfer    April Rent         $0.25      $0.003  $0.253
Apr 28        verify_identity      Jane Doe (app)     $1.00      $0.02   $1.02
Apr 27        link_session         Landlord setup     $0.50      $0.01   $0.51
```

The proxy guarantees this data is always available and always broken into its component parts. Displaying it is the browser app's responsibility.

---

## Data Models

```ruby
# Every capability execution — the billing and audit record
CapabilityLog:
  actor_id, capability, version, provider, provider_request_id
  raw_cost_cents, markup_cents, total_charged_cents
  charged_to, metadata_json, status, error_code
  invoked_at, completed_at

# Credit balance per actor
CreditAccount:
  actor_id
  balance_cents             # current available balance
  lifetime_charged_cents    # all-time total charged
  updated_at

# Credit top-up history
CreditTransaction:
  actor_id
  amount_cents
  type                      # "topup" | "deduction" | "refund"
  capability_log_id         # nil for topups
  created_at

# Encrypted provider credentials (access tokens, etc.)
ExternalItem:
  actor_id
  provider                  # "plaid", "stripe", etc.
  item_type                 # provider-specific type
  external_id               # provider's own ID
  access_token_encrypted    # AES-256-GCM encrypted at rest
  metadata_json
  created_at

# Opaque submission storage (for capabilities like submit_application)
SubmissionRecord:
  id, actor_id, capability
  listing_id                # or equivalent context identifier
  payload                   # encrypted blob (mode B) or structured JSON (mode A)
  status                    # "submitted" | "reviewed" | "accepted" | "rejected"
  idempotency_key
  created_at

# Event emission log
EventLog:
  id, event, actor_id
  capability_log_id         # the capability that emitted this event
  payload_json              # event data (no PII)
  processed_at
  created_at

# Workflow execution log
WorkflowLog:
  id, event_log_id
  capability                # downstream capability that was invoked
  status                    # "pending" | "success" | "failed"
  error_message
  executed_at
```

---

## API

### Single Dispatch Endpoint

```
POST /api/capability
  Body: signed envelope { actor_id, timestamp, capability, payload, signature }
  Returns: { status, submission_id?, metered_cost, raw_cost_cents, markup_cents }
```

All capability invocations go through this single endpoint. The dispatcher looks up the capability by name, validates the envelope, and routes execution.

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
                               breakdown_by_capability: [...],
                               breakdown_by_provider: [...],
                               call_count_this_month,
                               projected_next_month_cents
                             }
```

### Webhooks (no auth — validated by provider signature)

```
POST /api/webhooks/plaid
POST /api/webhooks/stripe
POST /api/webhooks/:provider    → generic webhook receiver
```

### Credits

```
GET  /api/credits/balance       → current balance + lifetime totals
POST /api/credits/topup         → add credits (via Stripe charge)
```

---

## File Structure

```
app/
├── capabilities/               # one file per capability
│   ├── base_capability.rb      # shared: validate → meter → store → emit
│   ├── submit_application.rb
│   ├── verify_income.rb
│   ├── verify_identity.rb
│   ├── initiate_transfer.rb
│   ├── link_session.rb
│   ├── exchange_token.rb
│   ├── poll_transfer_status.rb
│   ├── notify_landlord.rb
│   ├── notify_tenant.rb
│   └── generate_receipt.rb
│
├── controllers/
│   └── api/
│       ├── capability_controller.rb   # single dispatch endpoint
│       ├── auth_controller.rb
│       ├── usage_controller.rb
│       ├── credits_controller.rb
│       └── webhooks/
│           ├── plaid_controller.rb
│           └── stripe_controller.rb
│
├── models/
│   ├── capability_log.rb
│   ├── credit_account.rb
│   ├── credit_transaction.rb
│   ├── external_item.rb
│   ├── submission_record.rb
│   ├── event_log.rb
│   └── workflow_log.rb
│
└── services/
    ├── capability_dispatcher.rb    # envelope validation + capability routing
    ├── event_bus.rb                # emit events + trigger workflows
    ├── workflow_engine.rb          # reads workflows.yml, invokes downstream caps
    ├── signature_verifier.rb       # Ed25519 verification + replay protection
    └── cost_calculator.rb          # base_cost + markup → total, per cost type

config/
├── capabilities.yml            # capability registry (name → class mapping)
├── providers.yml               # provider cost config (base costs + default markups)
└── workflows.yml               # event → downstream capability chains
```

---

## Adding a New Integration

1. Create `app/capabilities/[name].rb` inheriting from `BaseCapability`
2. Define `DEFINITION` with capability name, version, description, cost
3. Implement `call(actor_id:, payload:, envelope:)` — validate, call provider, return result
4. Register in `config/capabilities.yml`
5. Add provider cost config to `config/providers.yml`
6. Add webhook controller under `api/webhooks/` if provider requires one
7. Add workflow entries to `config/workflows.yml` for any events this capability emits

The `log_usage` concern is handled by `BaseCapability` — subclasses never write billing records directly.

---

## Security Model

### Signature Verification

```ruby
# Ed25519 — verify every non-auth request
SignatureVerifier.verify!(
  signature: envelope[:signature],
  message:   canonical(envelope[:actor_id], envelope[:timestamp], envelope[:payload]),
  public_key: actor.public_key
)
```

### Replay Protection

```ruby
# Reject if timestamp outside ±5 minute window
raise ReplayError if (Time.now.to_i - envelope[:timestamp]).abs > 300

# Reject if signature hash already processed
raise ReplayError if IdempotencyRecord.exists?(hash: digest(envelope[:signature]))
```

### Payload Privacy (Mode B)

For capabilities that handle sensitive data (applications, income verification), the browser encrypts the payload before sending. The proxy stores an opaque blob — it never parses sensitive fields.

```
Browser                          Proxy
  │                                │
  │  encrypt(payload, key)         │
  │  → encrypted_blob              │
  │ ─────────────────────────────► │
  │                                │  stores blob only
  │                                │  never decrypts
  │ ◄───────────────────────────── │
  │  { status: "success",          │
  │    submission_id: "uuid",      │
  │    metered_cost: 1 }           │
```

### Observability — No PII in Logs

Application logs record only:

```
capability_log_id, actor_id, capability, status, total_charged_cents, duration_ms
```

Never logged: email addresses, names, phone numbers, application contents, financial account details.

---

## How Browser Apps Integrate

1. Register → receive JWT
2. Store JWT in local SQLite (never a cookie)
3. For every external API need, build a signed envelope and `POST /api/capability`
4. Store `capability_log_id` returned in every response in local SQLite for audit trail
5. Call `GET /api/usage/log` and `GET /api/usage/summary` to populate the cost transparency dashboard
6. Display `raw_cost_cents`, `markup_cents`, and `total_charged_cents` separately — never collapse them

---

## Environment Variables

```bash
# Rails
SECRET_KEY_BASE=

# Auth
JWT_SECRET=
JWT_EXPIRY_HOURS=720          # 30 days default

# App
APP_NAME=MyApp                # used in provider Link flows

# Plaid
PLAID_CLIENT_ID=
PLAID_SECRET=
PLAID_ENV=sandbox             # sandbox | development | production

# Stripe (for credit topups)
STRIPE_SECRET_KEY=
STRIPE_WEBHOOK_SECRET=

# CORS
FRONTEND_ORIGIN=https://yourapp.pages.dev

# Encryption (access tokens at rest)
ENCRYPTION_KEY=

# Default markup rate (overridden per provider in config/providers.yml)
DEFAULT_MARKUP_PERCENT=2
```

---

## Provider Cost Configuration

```yaml
# config/providers.yml
# Base costs are approximate — update when provider pricing changes
# Markup is what the proxy operator charges on top

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

  stripe:
    charge:
      base_cost_cents: 0        # Stripe fees deducted from payout, not pre-charged
      markup_percent: 0.5       # operator takes 0.5% on top of Stripe's 2.9%
    
  openai:
    chat_completion:
      base_cost_cents: 0        # variable — read from API response
      markup_percent: 10        # operator markup on token cost
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

## What Makes This Different from a BFF

A traditional Backend for Frontend couples tightly to one app's data model. This proxy is deliberately **decoupled**:

- No knowledge of the browser app's domain (properties, tenants, invoices, etc.)
- Entity IDs from the browser app are stored as opaque context in `metadata_json`
- Any local-first browser app can use this proxy by pointing at it and registering capabilities
- The capability + workflow model means the proxy stays minimal as integrations grow

---

## Roadmap

- [ ] `BaseCapability` class with shared validate/meter/store/emit lifecycle
- [ ] `CapabilityDispatcher` — single `POST /api/capability` routing
- [ ] `EventBus` + `WorkflowEngine` with `config/workflows.yml`
- [ ] `CreditAccount` model + topup via Stripe
- [ ] Ed25519 signature verification + replay protection
- [ ] `config/providers.yml` for operator-configurable cost + markup
- [ ] Stripe integration capability
- [ ] OpenAI integration capability
- [ ] SendGrid / email notification capability
- [ ] Server-Sent Events for webhook relay to browser
- [ ] Admin dashboard — usage across all actors
- [ ] Client library for browser apps (JS — wraps envelope signing + fetch)
- [ ] Rate limiting per actor per capability
