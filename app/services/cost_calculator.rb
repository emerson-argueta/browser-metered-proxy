class CostCalculator
  class << self
    def load_config!
      engine_yml = YAML.load_file(BrowserMeteredEngine::Engine.root.join("config/providers.yml"))

      host_yml_path = Rails.root.join("config/providers.yml")
      host_yml = (host_yml_path != BrowserMeteredEngine::Engine.root.join("config/providers.yml") &&
                  File.exist?(host_yml_path)) ? YAML.load_file(host_yml_path) : {}

      @config = engine_yml.deep_merge(host_yml).freeze
    end

    def config
      @config || load_config!
    end

    def calculate(provider:, capability:)
      cfg = config.dig("providers", provider.to_s, capability.to_s) || {}
      base           = cfg["base_cost_cents"] || 0
      markup_percent = cfg.fetch("markup_percent", ENV.fetch("DEFAULT_MARKUP_PERCENT", "0").to_f)
      markup         = (base * markup_percent / 100.0).ceil

      { raw_cost_cents: base, markup_cents: markup, total_charged_cents: base + markup }
    end
  end
end
