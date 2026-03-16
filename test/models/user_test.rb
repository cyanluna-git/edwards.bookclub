require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "requires a supported role" do
    user = User.new(email: "person@example.com", password: "secret123", role: "owner")

    assert_not user.valid?
    assert_includes user.errors[:role], "is not included in the list"
  end

  test "normalizes email addresses before validation" do
    user = User.create!(email: "  ADMIN@Example.com ", password: "secret123", role: "admin")

    assert_equal "admin@example.com", user.email
  end
end
