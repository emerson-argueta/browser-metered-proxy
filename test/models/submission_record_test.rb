require "test_helper"

class SubmissionRecordTest < ActiveSupport::TestCase
  def valid_attrs
    { actor_id: "1", capability: "submit_form", status: "submitted" }
  end

  test "valid with required fields" do
    assert SubmissionRecord.new(valid_attrs).valid?
  end

  test "invalid without actor_id" do
    record = SubmissionRecord.new(valid_attrs.except(:actor_id))
    assert_not record.valid?
    assert record.errors[:actor_id].any?
  end

  test "invalid without capability" do
    record = SubmissionRecord.new(valid_attrs.except(:capability))
    assert_not record.valid?
    assert record.errors[:capability].any?
  end

  test "invalid with unknown status" do
    record = SubmissionRecord.new(valid_attrs.merge(status: "unknown"))
    assert_not record.valid?
    assert record.errors[:status].any?
  end

  test "invalid with duplicate idempotency_key" do
    SubmissionRecord.create!(valid_attrs.merge(idempotency_key: "key_abc"))
    record = SubmissionRecord.new(valid_attrs.merge(idempotency_key: "key_abc"))
    assert_not record.valid?
    assert record.errors[:idempotency_key].any?
  end

  test "allows nil idempotency_key" do
    assert SubmissionRecord.new(valid_attrs.merge(idempotency_key: nil)).valid?
  end

  test "for_actor scope filters correctly" do
    rec = SubmissionRecord.create!(valid_attrs.merge(actor_id: "actor_x"))
    assert SubmissionRecord.for_actor("actor_x").include?(rec)
    assert_not SubmissionRecord.for_actor("actor_y").include?(rec)
  end
end
