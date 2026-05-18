module BrowserMeteredEngine
  class Engine < ::Rails::Engine
    # Non-isolated: models, controllers, and services live in the global namespace
    # so host apps can reference Actor, CapabilityDispatcher, BaseCapability, etc. directly.

    # After the host app's initializers run, merge capabilities and providers from both
    # the engine config and the host app config (host app wins on conflicts).
    initializer "browser_metered_engine.load_registry", after: :load_config_initializers do
      CapabilityDispatcher.load_registry!
      CostCalculator.load_config!
    end
  end
end
