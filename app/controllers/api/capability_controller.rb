module Api
  class CapabilityController < ApplicationController
    # GET /api/capability/quote?capability=sync_transactions
    def quote
      capability_name = params.require(:capability)
      class_name = CapabilityDispatcher.registry.dig("capabilities", capability_name)
      return render json: { error: "Unknown capability: #{capability_name}" }, status: :not_found unless class_name

      capability_class = class_name.constantize
      costs = CostCalculator.calculate(
        provider:   capability_class.provider.to_s,
        capability: capability_class.capability_name
      )
      render json: costs.merge(capability: capability_name, provider: capability_class.provider)
    rescue KeyError => e
      render json: { error: "Missing required param: #{e.message}" }, status: :unprocessable_entity
    end

    def invoke
      envelope = {}
      if params[:signature].present?
        envelope[:signature] = params[:signature].to_unsafe_h.symbolize_keys
      end

      result = CapabilityDispatcher.dispatch(
        capability_name: params.require(:capability),
        actor_id: @current_actor_id,
        payload: params[:payload]&.to_unsafe_h&.symbolize_keys || {},
        envelope: envelope
      )
      render json: result, status: :ok
    rescue CapabilityDispatcher::UnknownCapabilityError => e
      render json: { error: e.message }, status: :not_found
    rescue SignatureVerifier::InvalidSignatureError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue KeyError => e
      render json: { error: "Missing required param: #{e.message}" }, status: :unprocessable_entity
    rescue BetaModeError => e
      render json: { error: e.message, code: "beta_mode" }, status: :unprocessable_entity
    rescue Actor::InsufficientBalanceError => e
      render json: { error: e.message, code: "insufficient_balance" }, status: :payment_required
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Record not found" }, status: :not_found
    rescue Exception => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
