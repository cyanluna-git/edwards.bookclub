require "test_helper"

class MemberOfficeAssignmentTest < ActiveSupport::TestCase
  setup do
    @member = Member.create!(english_name: "Gerald Park", member_role: "정회원", location: "아산", active: true)
    @other_member = Member.create!(english_name: "James Jo", member_role: "정회원", location: "분당", active: true)
  end

  test "requires location for site leader assignments" do
    assignment = MemberOfficeAssignment.new(
      member: @member,
      office_type: "site_leader",
      effective_from: Date.new(2026, 1, 1)
    )

    assert_not assignment.valid?
    assert_includes assignment.errors[:location], "must be present for site leader assignments"
  end

  test "rejects location for global offices" do
    assignment = MemberOfficeAssignment.new(
      member: @member,
      office_type: "chairperson",
      location: "천안",
      effective_from: Date.new(2026, 1, 1)
    )

    assert_not assignment.valid?
    assert_includes assignment.errors[:location], "must be blank for global office assignments"
  end

  test "rejects overlapping assignments for the same office scope" do
    MemberOfficeAssignment.create!(
      member: @member,
      office_type: "site_leader",
      location: "아산",
      effective_from: Date.new(2026, 1, 1),
      effective_to: Date.new(2026, 3, 31)
    )

    assignment = MemberOfficeAssignment.new(
      member: @other_member,
      office_type: "site_leader",
      location: "아산",
      effective_from: Date.new(2026, 3, 1),
      effective_to: Date.new(2026, 4, 30)
    )

    assert_not assignment.valid?
    assert_includes assignment.errors[:base], "effective dates overlap an existing assignment for 아산"
  end

  test "allows handoff on the next day for the same office scope" do
    MemberOfficeAssignment.create!(
      member: @member,
      office_type: "secretary",
      effective_from: Date.new(2026, 1, 1),
      effective_to: Date.new(2026, 3, 31)
    )

    assignment = MemberOfficeAssignment.new(
      member: @other_member,
      office_type: "secretary",
      effective_from: Date.new(2026, 4, 1),
      effective_to: Date.new(2026, 12, 31)
    )

    assert assignment.valid?
  end
end
