module BrowserMeteredEngine
  class Engine < ::Rails::Engine
    # Non-isolated: models, controllers, and services live in the global namespace
    # so host apps can reference Actor, CapabilityDispatcher, BaseCapability, etc. directly.

    # After the host app's initializers run, merge capabilities and providers from both
    # the engine config and the host app config (host app wins on conflicts).
    # CapabilityDispatcher.registry and CostCalculator.config are lazy-loaded
    # on first use, merging engine config with the host app's overrides.
    # No explicit boot-time loading needed.
  end
end
