module Api
  class CapabilityController < ApplicationController
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
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Record not found" }, status: :not_found
    rescue => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end
end
