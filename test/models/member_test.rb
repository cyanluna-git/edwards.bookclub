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

  test "returns effective office labels for a date" do
    member = Member.create!(english_name: "Gerald Park", member_role: "정회원", location: "아산", active: true)
    member.member_office_assignments.create!(
      office_type: "site_leader",
      location: "아산",
      effective_from: Date.new(2026, 1, 1),
      effective_to: Date.new(2026, 12, 31)
    )

    assert_equal ["지역 리더 · 아산"], member.office_labels_on(Date.new(2026, 6, 1))
  end
end
