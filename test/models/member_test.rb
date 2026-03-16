require "test_helper"

class MemberTest < ActiveSupport::TestCase
  test "requires english name and member role" do
    member = Member.new

    assert_not member.valid?
    assert_includes member.errors[:english_name], "can't be blank"
    assert_includes member.errors[:member_role], "can't be blank"
  end

  test "detects leader roles from role text" do
    member = Member.new(english_name: "Gerald Park", member_role: "Lead:총무")

    assert member.leader_role?
  end
end
