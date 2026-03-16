require "test_helper"

class AuthenticationFlowTest < ActionDispatch::IntegrationTest
  setup do
    [MeetingPhoto, MeetingAttendance, Meeting, BookRequest, User, Member, ReservePolicy, FiscalPeriod].each(&:delete_all)

    @member = Member.create!(english_name: "Hannah Lee", member_role: "정회원", active: true, email: "hannah@example.com")
    @admin = User.create!(email: "admin@example.com", password: "secret123", password_confirmation: "secret123", role: "admin")
    @member_user = User.create!(email: "member@example.com", password: "secret123", password_confirmation: "secret123", role: "member", member: @member)
  end

  test "signs in and signs out successfully" do
    post session_path, params: { email: @admin.email, password: "secret123" }

    assert_redirected_to root_path
    follow_redirect!
    assert_response :success
    assert_match "Signed in as", response.body

    delete destroy_session_path

    assert_redirected_to new_session_path
    follow_redirect!
    assert_match "Signed out successfully.", response.body
  end

  test "rejects invalid credentials" do
    post session_path, params: { email: @admin.email, password: "wrong-pass" }

    assert_response :unprocessable_content
    assert_match "Invalid email or password.", response.body
  end

  test "redirects anonymous users away from protected pages" do
    get root_path

    assert_redirected_to new_session_path

    get admin_dashboard_path

    assert_redirected_to new_session_path
  end

  test "member users can resolve the linked member but cannot access admin" do
    post session_path, params: { email: @member_user.email, password: "secret123" }
    follow_redirect!

    assert_response :success
    assert_match "Linked member: Hannah Lee", response.body

    get admin_dashboard_path

    assert_redirected_to root_path
    follow_redirect!
    assert_match "You are not authorized to access that page.", response.body
  end
end
