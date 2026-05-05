require "test_helper"

class CapabilityLogTest < ActiveSupport::TestCase
  def valid_attrs
    {
      actor_id: "1",
      capability: "link_session",
      status: "success",
      invoked_at: Time.current
    }
  end

  test "valid with required fields" do
    log = CapabilityLog.new(valid_attrs)
    assert log.valid?
  end

  test "invalid without actor_id" do
    log = CapabilityLog.new(valid_attrs.except(:actor_id))
    assert_not log.valid?
    assert log.errors[:actor_id].any?
  end

  test "invalid without capability" do
    log = CapabilityLog.new(valid_attrs.except(:capability))
    assert_not log.valid?
    assert log.errors[:capability].any?
  end

  test "invalid with unknown status" do
    log = CapabilityLog.new(valid_attrs.merge(status: "pending"))
    assert_not log.valid?
    assert log.errors[:status].any?
  end

  test "for_actor scope filters by actor" do
    log = capability_logs(:one)
    assert CapabilityLog.for_actor(log.actor_id).include?(log)
    assert_not CapabilityLog.for_actor("nobody").include?(log)
  end

  test "this_month scope returns only current month records" do
    log = capability_logs(:one)
    log.update!(invoked_at: Time.current)
    assert CapabilityLog.this_month.include?(log)
  end
end
