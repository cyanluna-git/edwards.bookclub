require "test_helper"

class AdminMembersFlowTest < ActionDispatch::IntegrationTest
  setup do
    [MeetingPhoto, MeetingAttendance, Meeting, BookRequest, User, Member, ReservePolicy, FiscalPeriod].each(&:delete_all)

    @period = FiscalPeriod.create!(name: "FY2026", start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 12, 31), active: true)
    ReservePolicy.create!(member_role: "정회원", attendance_points: 5000, effective_from: @period.start_date, effective_to: @period.end_date)
    ReservePolicy.create!(member_role: "Lead", attendance_points: 10000, effective_from: @period.start_date, effective_to: @period.end_date)

    @active_member = Member.create!(english_name: "Hannah Lee", korean_name: "이현아", email: "hannah@example.com", department: "Planning", member_role: "정회원", location: "천안", active: true)
    @inactive_member = Member.create!(english_name: "Min Seo", korean_name: "민서", email: "min@example.com", department: "Quality", member_role: "Lead", location: "분당", active: false)
    @meeting = Meeting.create!(title: "March Meetup", meeting_at: Time.zone.parse("2026-03-10 19:00"), fiscal_period: @period)
    MeetingAttendance.create!(meeting: @meeting, member: @active_member)
    BookRequest.create!(member: @active_member, title: "Thinking in Systems", fiscal_period: @period)

    @admin = User.create!(email: "admin@example.com", password: "secret123", password_confirmation: "secret123", role: "admin")
    @member_user = User.create!(email: "member@example.com", password: "secret123", password_confirmation: "secret123", role: "member", member: @active_member)
  end

  test "admin can search and filter members" do
    sign_in_as(@admin)

    get admin_members_path, params: { q: "Hannah", active: "active", role: "정회원", location: "천안" }

    assert_response :success
    assert_match "Hannah Lee", response.body
    assert_no_match "Min Seo", response.body
  end

  test "admin can create and update a member" do
    sign_in_as(@admin)

    post admin_members_path, params: {
      member: {
        english_name: "Book Kim",
        korean_name: "김북",
        email: "book@example.com",
        department: "Finance",
        member_role: "정회원",
        location: "아산",
        joined_on: "2026-03-01",
        bio: "Runs the monthly agenda.",
        active: "true"
      }
    }

    created_member = Member.find_by!(email: "book@example.com")
    assert_redirected_to admin_member_path(created_member)
    follow_redirect!
    assert_match "Member created successfully.", response.body
    assert_match "Runs the monthly agenda.", response.body

    patch admin_member_path(created_member), params: {
      member: {
        department: "Operations",
        member_role: "Lead",
        location: "분당",
        active: "false"
      }
    }

    assert_redirected_to admin_member_path(created_member)
    created_member.reload
    assert_equal "Operations", created_member.department
    assert_equal "Lead", created_member.member_role
    assert_not created_member.active?
  end

  test "admin can deactivate and reactivate a member" do
    sign_in_as(@admin)

    patch deactivate_admin_member_path(@active_member)

    assert_redirected_to admin_member_path(@active_member)
    assert_not @active_member.reload.active?

    patch reactivate_admin_member_path(@active_member)

    assert_redirected_to admin_member_path(@active_member)
    assert @active_member.reload.active?
  end

  test "member users cannot access admin member screens" do
    sign_in_as(@member_user)

    get admin_members_path

    assert_redirected_to root_path
    follow_redirect!
    assert_redirected_to member_root_path
    follow_redirect!
    assert_match "You are not authorized to access that page.", response.body
  end

  test "member detail shows operational context" do
    sign_in_as(@admin)

    get admin_member_path(@active_member)

    assert_response :success
    assert_match "Attendance rows", response.body
    assert_match "Book requests", response.body
    assert_match "Thinking in Systems", response.body
  end

  private

  def sign_in_as(user)
    post session_path, params: { email: user.email, password: "secret123" }
    follow_redirect!
  end
end
