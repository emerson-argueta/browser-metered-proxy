class CapabilityDispatcher
  class UnknownCapabilityError < StandardError; end

  class << self
    def load_registry!
      engine_yml = YAML.load_file(BrowserMeteredEngine::Engine.root.join("config/capabilities.yml"))

      host_yml_path = Rails.root.join("config/capabilities.yml")
      host_yml = (host_yml_path != BrowserMeteredEngine::Engine.root.join("config/capabilities.yml") &&
                  File.exist?(host_yml_path)) ? YAML.load_file(host_yml_path) : {}

      @registry = engine_yml.deep_merge(host_yml).freeze
    end

    def registry
      @registry || load_registry!
    end

    def dispatch(capability_name:, actor_id:, payload:, envelope: {})
      class_name = registry.dig("capabilities", capability_name)
      raise UnknownCapabilityError, "Unknown capability: #{capability_name}" unless class_name

      capability_class = class_name.constantize
      capability_class.new(actor_id: actor_id, payload: payload, envelope: envelope).execute
    end
  end
end
