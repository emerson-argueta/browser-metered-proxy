# Contributing to browser-metered-proxy

Thanks for your interest in contributing. This is a minimal project and we want to keep it that way — contributions that add complexity without clear value will be declined.

## What we welcome

- Bug fixes
- New provider capability implementations (Stripe, OpenAI, etc.)
- Documentation improvements
- Test coverage
- Security fixes

## What we won't merge

- Business logic that belongs in the browser app
- Workflow orchestration or capability chaining
- Features that couple the proxy to a specific domain (property management, e-commerce, etc.)
- Abstractions that aren't justified by at least two real use cases

## Setup

```bash
git clone https://github.com/emerson-argueta/browser-metered-proxy
cd browser-metered-proxy
bundle install
cp .env.example .env   # fill in at minimum JWT_SECRET and ENCRYPTION_KEY
bin/rails db:migrate
bin/rails server
```

## Running tests

```bash
bin/rails test
```

## Adding a new capability

The most common contribution is a new provider integration. Follow this pattern:

**1. Create the capability class**

```ruby
# app/capabilities/[provider]/[name].rb
module Capabilities
  module YourProvider
    class YourCapability < BaseCapability
      include YourProviderCapability  # shared client setup

      DEFINITION = {
        capability: "your_capability",
        version: "1.0",
        provider: "your_provider",
        cost: { type: "passthrough" }  # or "fixed", "free", "variable"
      }.freeze

      def call
        # 1. Validate payload — use payload.fetch(:key) for required fields
        # 2. Call the external provider
        # 3. Return a hash with the result and provider_request_id
        {
          result: response.data,
          provider_request_id: response.request_id
        }
      end
    end
  end
end
```

**2. Add a shared client concern**

```ruby
# app/capabilities/[provider]/[provider]_capability.rb
module Capabilities
  module YourProvider
    module YourProviderCapability
      private

      def client
        @client ||= YourProviderSdk.new(api_key: ENV.fetch("YOUR_PROVIDER_API_KEY"))
      end
    end
  end
end
```

**3. Register the capability**

```yaml
# config/capabilities.yml
capabilities:
  your_capability: "Capabilities::YourProvider::YourCapability"
```

**4. Add cost config**

```yaml
# config/providers.yml
providers:
  your_provider:
    your_capability:
      base_cost_cents: 100
      markup_percent: 2
```

**5. Add env vars to `.env.example`**

```bash
# Your Provider
YOUR_PROVIDER_API_KEY=
```

**6. Add a webhook controller if the provider requires one**

```ruby
# app/controllers/api/webhooks/your_provider_controller.rb
module Api
  module Webhooks
    class YourProviderController < ApplicationController
      skip_before_action :authenticate_actor!

      def receive
        # validate provider signature, handle event
        head :ok
      end
    end
  end
end
```

And add the route:

```ruby
namespace :webhooks do
  post "your_provider", to: "your_provider#receive"
end
```

## Cost types

| Type | When to use |
|------|-------------|
| `passthrough` | Provider charges a real fee per call (Plaid, Stripe) |
| `fixed` | Flat charge regardless of provider cost (SendGrid) |
| `free` | No charge — status checks, read-only calls |
| `variable` | Cost depends on payload (OpenAI token count) |

For `passthrough` capabilities, `raw_cost_cents` should reflect what the provider actually charged, read from the API response where possible.

## Pull request checklist

- [ ] Capability inherits from `BaseCapability` and uses `payload.fetch` for required fields
- [ ] Registered in `config/capabilities.yml`
- [ ] Cost config added to `config/providers.yml`
- [ ] New env vars added to `.env.example`
- [ ] Tests added for the capability and any new models
- [ ] No business logic — the capability does one thing and returns

## Reporting issues

Open an issue at https://github.com/emerson-argueta/browser-metered-proxy/issues. Include the capability name, payload shape, and the error or unexpected behavior.
