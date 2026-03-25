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

  test "chairperson can manage the club without explicit admin role" do
    member = Member.create!(english_name: "Gerald Park", member_role: "정회원", active: true)
    member.member_office_assignments.create!(office_type: "chairperson", effective_from: Date.current.beginning_of_year)
    user = User.create!(email: "gerald@example.com", password: "secret123", role: "member", member: member)

    assert user.can_manage_club?
    assert_equal "Chairperson", user.management_access_label
  end

  test "site leader can manage members without full club access" do
    member = Member.create!(english_name: "Hannah Lee", member_role: "Lead", location: "분당", active: true)
    member.member_office_assignments.create!(office_type: "site_leader", location: "분당", effective_from: Date.current.beginning_of_year)
    user = User.create!(email: "hannah@example.com", password: "secret123", role: "member", member: member)

    assert user.can_manage_members?
    assert_not user.can_manage_club?
    assert_equal "Site leader", user.management_access_label
  end
end
