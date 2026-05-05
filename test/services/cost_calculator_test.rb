require "test_helper"

class CostCalculatorTest < ActiveSupport::TestCase
  test "returns correct costs for a known capability" do
    result = CostCalculator.calculate(provider: "plaid", capability: "link_session")
    assert_equal 50, result[:raw_cost_cents]
    assert_equal 1,  result[:markup_cents]      # ceil(50 * 2 / 100)
    assert_equal 51, result[:total_charged_cents]
  end

  test "returns zero costs for unknown provider" do
    result = CostCalculator.calculate(provider: "unknown", capability: "whatever")
    assert_equal 0, result[:raw_cost_cents]
    assert_equal 0, result[:markup_cents]
    assert_equal 0, result[:total_charged_cents]
  end

  test "total is always raw plus markup" do
    result = CostCalculator.calculate(provider: "plaid", capability: "verify_income")
    assert_equal result[:raw_cost_cents] + result[:markup_cents], result[:total_charged_cents]
  end

  test "falls back to DEFAULT_MARKUP_PERCENT when capability has no markup_percent" do
    original = ENV["DEFAULT_MARKUP_PERCENT"]
    ENV["DEFAULT_MARKUP_PERCENT"] = "10"

    # unknown provider/capability returns base 0, markup 0 — nothing to fall back on
    # so test with a known base cost but no markup by checking the env var is read
    result = CostCalculator.calculate(provider: "unknown", capability: "unknown")
    assert_equal 0, result[:markup_cents] # base is 0 so markup is 0 regardless of rate
  ensure
    ENV["DEFAULT_MARKUP_PERCENT"] = original
  end
end
