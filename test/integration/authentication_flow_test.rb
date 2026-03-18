require "test_helper"

class AuthenticationFlowTest < ActionDispatch::IntegrationTest
  setup do
    [ MeetingPhoto, MeetingAttendance, Meeting, BookRequest, User, Member, ReservePolicy, FiscalPeriod ].each(&:delete_all)

    @member = Member.create!(english_name: "Hannah Lee", member_role: "정회원", active: true, email: "hannah@example.com")
    @admin = User.create!(email: "admin@example.com", password: "secret123", password_confirmation: "secret123", role: "admin")
    @member_user = User.create!(email: "member@example.com", password: "secret123", password_confirmation: "secret123", role: "member", member: @member)
  end

  test "signs in and signs out successfully" do
    post session_path, params: { email: @admin.email, password: "secret123" }

    assert_redirected_to root_path
    follow_redirect!
    assert_redirected_to reports_path
    follow_redirect!
    assert_response :success
    assert_match "Reports", response.body

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
    assert_redirected_to reports_path
    follow_redirect!

    assert_response :success
    assert_match "Reports", response.body

    get admin_dashboard_path

    assert_redirected_to root_path
    follow_redirect!
    assert_redirected_to reports_path
    follow_redirect!
    assert_match "You are not authorized to access that page.", response.body
  end

  test "sso signs in an existing user from a trusted email header" do
    with_env(
      "BOOKCLUB_SSO_ENABLED" => "true",
      "BOOKCLUB_SSO_EMAIL_HEADERS" => "X-Bookclub-Sso-Email"
    ) do
      get sso_callback_path, headers: { "X-Bookclub-Sso-Email" => @admin.email }

      assert_redirected_to root_path
      follow_redirect!
      assert_redirected_to reports_path
      follow_redirect!

      assert_response :success
      assert_match "Signed in with SSO.", response.body
    end
  end

  test "sso auto-provisions a linked member user from member email" do
    sso_member = Member.create!(
      english_name: "Gerald Park",
      member_role: "정회원",
      active: true,
      email: "gerald.sso@example.com"
    )

    with_env(
      "BOOKCLUB_SSO_ENABLED" => "true",
      "BOOKCLUB_SSO_EMAIL_HEADERS" => "X-Bookclub-Sso-Email"
    ) do
      assert_difference("User.count", 1) do
        get sso_callback_path, headers: { "X-Bookclub-Sso-Email" => sso_member.email }
      end

      user = User.find_by!(email: sso_member.email)
      assert_equal sso_member, user.member
      assert_equal "member", user.role

      assert_redirected_to root_path
    end
  end

  test "sign-in page advertises sso and can redirect to the upstream login url" do
    with_env(
      "BOOKCLUB_SSO_ENABLED" => "true",
      "BOOKCLUB_SSO_LOGIN_URL" => "https://oqc.10.82.37.79.sslip.io/sso/bookclub",
      "BOOKCLUB_SSO_AUTO_REDIRECT" => "false"
    ) do
      get new_session_path
      assert_response :success
      assert_match "Sign in with Edwards SSO", response.body

      get sso_session_path
      assert_redirected_to "https://oqc.10.82.37.79.sslip.io/sso/bookclub"
    end
  end
end
