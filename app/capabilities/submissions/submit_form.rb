module Submissions
  class SubmitForm < BaseCapability
    DEFINITION = {
      capability: "submit_form",
      version: "1.0",
      provider: nil,
      cost: { type: "free" }
    }.freeze

    def call
      verify_signature! if envelope[:signature].present?

      idempotency_key = payload[:idempotency_key]

      if idempotency_key
        existing = SubmissionRecord.find_by(idempotency_key: idempotency_key)
        return { submission_id: existing.id, status: existing.status, provider_request_id: nil } if existing
      end

      record = SubmissionRecord.create!(
        actor_id: actor_id,
        capability: "submit_form",
        payload: payload[:data]&.to_json,
        signature: envelope.dig(:signature, :value),
        public_key: envelope.dig(:signature, :public_key),
        status: "submitted",
        idempotency_key: idempotency_key
      )

      { submission_id: record.id, status: record.status, provider_request_id: nil }
    end

    private

    def verify_signature!
      sig = envelope[:signature]
      SignatureVerifier.verify!(
        signature: sig.fetch(:value),
        public_key: sig.fetch(:public_key),
        message: SignatureVerifier.canonical_message("submit_form", payload)
      )
    end
  end
end
