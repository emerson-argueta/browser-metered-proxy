require "test_helper"

class CapabilityDispatcherTest < ActiveSupport::TestCase
  test "raises UnknownCapabilityError for unregistered capability" do
    assert_raises CapabilityDispatcher::UnknownCapabilityError do
      CapabilityDispatcher.dispatch(
        capability_name: "does_not_exist",
        actor_id: "1",
        payload: {}
      )
    end
  end
end
