require "test_helper"

class ExternalItemTest < ActiveSupport::TestCase
  def valid_attrs
    {
      actor_id: "1",
      provider: "plaid",
      external_id: "item_unique_#{SecureRandom.hex(4)}"
    }
  end

  test "valid with required fields" do
    item = ExternalItem.new(valid_attrs)
    assert item.valid?
  end

  test "invalid without actor_id" do
    item = ExternalItem.new(valid_attrs.except(:actor_id))
    assert_not item.valid?
    assert item.errors[:actor_id].any?
  end

  test "invalid without provider" do
    item = ExternalItem.new(valid_attrs.except(:provider))
    assert_not item.valid?
    assert item.errors[:provider].any?
  end

  test "invalid with duplicate external_id" do
    ExternalItem.create!(valid_attrs.merge(external_id: "item_dupe"))
    item = ExternalItem.new(valid_attrs.merge(external_id: "item_dupe"))
    assert_not item.valid?
    assert item.errors[:external_id].any?
  end

  test "for_actor scope filters by actor" do
    item = external_items(:one)
    assert ExternalItem.for_actor(item.actor_id).include?(item)
    assert_not ExternalItem.for_actor("nobody").include?(item)
  end

  test "for_provider scope filters by provider" do
    item = external_items(:one)
    assert ExternalItem.for_provider("plaid").include?(item)
    assert_not ExternalItem.for_provider("stripe").include?(item)
  end
end
