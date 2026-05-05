require "test_helper"

class SignatureVerifierTest < ActiveSupport::TestCase
  def setup
    @signing_key = Ed25519::SigningKey.generate
    @verify_key  = @signing_key.verify_key
    @public_key  = Base64.strict_encode64(@verify_key.to_bytes)
  end

  def sign(message)
    Base64.strict_encode64(@signing_key.sign(message))
  end

  test "verifies a valid signature" do
    message   = SignatureVerifier.canonical_message("submit_form", { data: "test" })
    signature = sign(message)

    assert_nothing_raised do
      SignatureVerifier.verify!(signature: signature, public_key: @public_key, message: message)
    end
  end

  test "raises InvalidSignatureError for tampered message" do
    message   = SignatureVerifier.canonical_message("submit_form", { data: "original" })
    signature = sign(message)
    tampered  = SignatureVerifier.canonical_message("submit_form", { data: "tampered" })

    assert_raises SignatureVerifier::InvalidSignatureError do
      SignatureVerifier.verify!(signature: signature, public_key: @public_key, message: tampered)
    end
  end

  test "raises InvalidSignatureError for wrong key" do
    other_key = Ed25519::SigningKey.generate
    message   = SignatureVerifier.canonical_message("submit_form", { data: "test" })
    signature = Base64.strict_encode64(other_key.sign(message))

    assert_raises SignatureVerifier::InvalidSignatureError do
      SignatureVerifier.verify!(signature: signature, public_key: @public_key, message: message)
    end
  end

  test "raises InvalidSignatureError for malformed base64" do
    assert_raises SignatureVerifier::InvalidSignatureError do
      SignatureVerifier.verify!(signature: "not-base64!!!", public_key: @public_key, message: "msg")
    end
  end

  test "canonical_message produces consistent output" do
    payload = { data: "test" }
    assert_equal SignatureVerifier.canonical_message("submit_form", payload),
                 SignatureVerifier.canonical_message("submit_form", payload)
  end
end
