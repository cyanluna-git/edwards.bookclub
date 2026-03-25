require "test_helper"

class AdminOfficeAssignmentsFlowTest < ActionDispatch::IntegrationTest
  setup do
    [ MeetingPhoto, MeetingAttendance, Meeting, MemberOfficeAssignment, BookRequest, User, Member, ReservePolicy, FiscalPeriod ].each(&:delete_all)

    @period = FiscalPeriod.create!(name: "FY2026", start_date: Date.current.beginning_of_year, end_date: Date.current.end_of_year, active: true)
    @member = Member.create!(english_name: "Gerald Park", korean_name: "박근윤", email: "gerald@example.com", member_role: "정회원", location: "아산", active: true)
    @other_member = Member.create!(english_name: "Jim Kim", korean_name: "김형진", email: "jim@example.com", member_role: "정회원", location: "아산", active: true)
    @admin = User.create!(email: "admin@example.com", password: "secret123", password_confirmation: "secret123", role: "admin")
    @member_user = User.create!(email: "member@example.com", password: "secret123", password_confirmation: "secret123", role: "member", member: @member)
  end

  test "admin can access office assignments workspace and see history sections" do
    @member.member_office_assignments.create!(office_type: "chairperson", effective_from: Date.current - 2.days)
    @other_member.member_office_assignments.create!(office_type: "site_leader", location: "분당", effective_from: Date.current + 7.days)
    @member.member_office_assignments.create!(office_type: "secretary", effective_from: Date.current - 14.days, effective_to: Date.current - 1.day)

    sign_in_as(@admin)
    get admin_office_assignments_path

    assert_response :success
    assert_match "Office Assignments", response.body
    assert_match "Active assignments", response.body
    assert_match "Upcoming assignments", response.body
    assert_match "History", response.body
    assert_match "Reserve bonus applies", response.body
    assert_match "Display / access role only", response.body
  end

  test "admin can create edit end and delete office assignments" do
    sign_in_as(@admin)

    post admin_office_assignments_path, params: {
      office_assignment: {
        member_id: @member.id,
        office_type: "site_leader",
        location: "아산",
        effective_from: Date.current.iso8601,
        effective_to: ""
      }
    }

    assignment = @member.member_office_assignments.find_by!(office_type: "site_leader", location: "아산")
    assert_redirected_to admin_office_assignments_path(member_id: @member.id)
    assert_equal @admin, assignment.created_by

    patch admin_office_assignment_path(assignment), params: {
      office_assignment: {
        member_id: @member.id,
        office_type: "site_leader",
        location: "천안",
        effective_from: Date.current.iso8601,
        effective_to: ""
      }
    }

    assert_redirected_to admin_office_assignments_path(member_id: @member.id)
    assert_equal "천안", assignment.reload.location

    patch end_assignment_admin_office_assignment_path(assignment), params: { effective_to: (Date.current + 5.days).iso8601 }

    assert_redirected_to admin_office_assignments_path(member_id: @member.id)
    assert_equal Date.current + 5.days, assignment.reload.effective_to

    delete admin_office_assignment_path(assignment)

    assert_redirected_to admin_office_assignments_path(member_id: @member.id)
    assert_nil MemberOfficeAssignment.find_by(id: assignment.id)
  end

  test "office assignments screen rejects invalid site leader rows and overlapping scopes" do
    sign_in_as(@admin)

    post admin_office_assignments_path, params: {
      office_assignment: {
        member_id: @member.id,
        office_type: "site_leader",
        location: "",
        effective_from: Date.current.iso8601,
        effective_to: ""
      }
    }

    assert_response :unprocessable_content
    assert_match "Location must be present for site leader assignments", response.body

    @member.member_office_assignments.create!(office_type: "site_leader", location: "아산", effective_from: Date.current)

    post admin_office_assignments_path, params: {
      office_assignment: {
        member_id: @other_member.id,
        office_type: "site_leader",
        location: "아산",
        effective_from: Date.current.iso8601,
        effective_to: ""
      }
    }

    assert_response :unprocessable_content
    assert_match "effective dates overlap an existing assignment for 아산", response.body
  end

  test "member users cannot access office assignments screens" do
    sign_in_as(@member_user)

    get admin_office_assignments_path

    assert_redirected_to root_path
  end

  private

  def sign_in_as(user)
    post session_path, params: { email: user.email, password: "secret123" }
    follow_redirect!
  end
end
