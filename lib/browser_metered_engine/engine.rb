module BrowserMeteredEngine
  class Engine < ::Rails::Engine
    # Non-isolated: models, controllers, and services live in the global namespace
    # so host apps can reference Actor, CapabilityDispatcher, BaseCapability, etc. directly.

    # Add the engine's migrations to the host app's migration paths so
    # `bin/rails db:migrate` picks them up automatically.
    initializer "browser_metered_engine.migration_paths", before: :load_config_initializers do |app|
      app.config.paths["db/migrate"] << Engine.root.join("db/migrate").to_s
    end

    # CapabilityDispatcher.registry and CostCalculator.config are lazy-loaded
    # on first use, merging engine config with the host app's overrides.
  end
end
