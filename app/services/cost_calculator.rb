class CostCalculator
  CONFIG = YAML.load_file(Rails.root.join("config/providers.yml")).freeze

  def self.calculate(provider:, capability:)
    config = CONFIG.dig("providers", provider, capability) || {}
    base = config["base_cost_cents"] || 0
    markup_percent = config.fetch("markup_percent", ENV.fetch("DEFAULT_MARKUP_PERCENT", "0").to_f)
    markup = (base * markup_percent / 100.0).ceil

    { raw_cost_cents: base, markup_cents: markup, total_charged_cents: base + markup }
  end
end
