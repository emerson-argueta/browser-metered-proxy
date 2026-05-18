require_relative "lib/browser_metered_engine/version"

Gem::Specification.new do |s|
  s.name        = "browser_metered_engine"
  s.version     = BrowserMeteredEngine::VERSION
  s.authors     = ["Emerson Argueta"]
  s.email       = ["emersonargueta92@gmail.com"]
  s.summary     = "Rails engine providing metered API proxy infrastructure"
  s.description = "Actor auth, credit billing, capability dispatch, and built-in Plaid/Stripe/SendGrid capabilities. Mount this engine in any Rails API app and add your own capabilities on top."
  s.license     = "MIT"

  s.required_ruby_version = ">= 3.3"

  s.files = Dir[
    "{app,config,db,lib}/**/*",
    "LICENSE",
    "README.md"
  ].reject { |f| f.include?("spec/") || f.include?("test/") }

  s.add_dependency "rails",          ">= 8.0"
  s.add_dependency "bcrypt",         "~> 3.1.7"
  s.add_dependency "jwt"
  s.add_dependency "rack-cors"
  s.add_dependency "rack-attack"
  s.add_dependency "plaid"
  s.add_dependency "stripe"
  s.add_dependency "resend"
  s.add_dependency "attr_encrypted", "~> 4.0"
  s.add_dependency "ed25519"
end
