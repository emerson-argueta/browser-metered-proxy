require "test_helper"

class ActorTest < ActiveSupport::TestCase
  test "valid with email and password" do
    actor = Actor.new(email: "new@example.com", password: "password", password_confirmation: "password")
    assert actor.valid?
  end

  test "invalid without email" do
    actor = Actor.new(password: "password", password_confirmation: "password")
    assert_not actor.valid?
    assert_includes actor.errors[:email], "can't be blank"
  end

  test "invalid with malformed email" do
    actor = Actor.new(email: "notanemail", password: "password", password_confirmation: "password")
    assert_not actor.valid?
    assert actor.errors[:email].any?
  end

  test "invalid with duplicate email" do
    Actor.create!(email: "dupe@example.com", password: "password", password_confirmation: "password")
    actor = Actor.new(email: "dupe@example.com", password: "password", password_confirmation: "password")
    assert_not actor.valid?
    assert actor.errors[:email].any?
  end

  test "email is downcased before save" do
    actor = Actor.create!(email: "UPPER@EXAMPLE.COM", password: "password", password_confirmation: "password")
    assert_equal "upper@example.com", actor.email
  end

  test "authenticate returns actor with correct password" do
    actor = Actor.create!(email: "auth@example.com", password: "secret", password_confirmation: "secret")
    assert actor.authenticate("secret")
  end

  test "authenticate returns false with wrong password" do
    actor = Actor.create!(email: "auth2@example.com", password: "secret", password_confirmation: "secret")
    assert_not actor.authenticate("wrong")
  end
end
