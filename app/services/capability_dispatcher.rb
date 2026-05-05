class CapabilityDispatcher
  REGISTRY = YAML.load_file(Rails.root.join("config/capabilities.yml")).freeze

  class UnknownCapabilityError < StandardError; end

  def self.dispatch(capability_name:, actor_id:, payload:, envelope: {})
    class_name = REGISTRY.dig("capabilities", capability_name)
    raise UnknownCapabilityError, "Unknown capability: #{capability_name}" unless class_name

    capability_class = class_name.constantize
    capability_class.new(actor_id: actor_id, payload: payload, envelope: envelope).execute
  end
end
