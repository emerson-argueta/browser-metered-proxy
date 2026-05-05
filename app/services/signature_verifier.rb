class SignatureVerifier
  class InvalidSignatureError < StandardError; end

  def self.verify!(signature:, public_key:, message:)
    verify_key = Ed25519::VerifyKey.new(Base64.strict_decode64(public_key))
    sig_bytes  = Base64.strict_decode64(signature)
    verify_key.verify(sig_bytes, message)
  rescue Ed25519::VerifyError, ArgumentError
    raise InvalidSignatureError, "Invalid signature"
  end

  def self.canonical_message(capability, payload)
    "#{capability}:#{payload.to_json}"
  end
end
