require "test_helper"

class SsoFlowTest < ActionDispatch::IntegrationTest
  setup do
    [MeetingPhoto, MeetingAttendance, Meeting, BookRequest, User, Member, ReservePolicy, FiscalPeriod].each(&:delete_all)

    @member = Member.create!(english_name: "Hannah Lee", member_role: "정회원", active: true, email: "hannah@example.com")
    @user = User.create!(
      email: "hannah@corp.example.com",
      password: "irrelevant-for-sso",
      password_confirmation: "irrelevant-for-sso",
      role: "member",
      member: @member
    )
    @admin = User.create!(
      email: "admin@corp.example.com",
      password: "irrelevant-for-sso",
      password_confirmation: "irrelevant-for-sso",
      role: "admin"
    )

    OmniAuth.config.test_mode = true
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:entra_id] = nil
  end

  # ---------------------------------------------------------------------------
  # Successful callbacks
  # ---------------------------------------------------------------------------

  test "successful SSO callback creates Rails session and redirects to root" do
    OmniAuth.config.mock_auth[:entra_id] = mock_auth_hash(@user.email)

    post "/auth/entra_id"
    follow_redirect!
    assert_redirected_to root_path
    assert_equal "Signed in with Microsoft successfully.", flash[:notice]
  end

  test "successful SSO callback is case-insensitive on email" do
    OmniAuth.config.mock_auth[:entra_id] = mock_auth_hash(@user.email.upcase)

    post "/auth/entra_id"
    follow_redirect!
    assert_redirected_to root_path
  end

  test "admin can sign in via SSO" do
    OmniAuth.config.mock_auth[:entra_id] = mock_auth_hash(@admin.email)

    post "/auth/entra_id"
    follow_redirect!
    assert_redirected_to root_path
  end

  # ---------------------------------------------------------------------------
  # Unknown / unlinked user
  # ---------------------------------------------------------------------------

  test "unknown email is rejected and redirected to sign-in" do
    OmniAuth.config.mock_auth[:entra_id] = mock_auth_hash("nobody@corp.example.com")

    post "/auth/entra_id"
    follow_redirect!
    assert_redirected_to new_session_path
    follow_redirect!
    assert_match "No Bookclub account is linked to nobody@corp.example.com", response.body
  end

  test "rejected SSO attempt leaves session unauthenticated" do
    OmniAuth.config.mock_auth[:entra_id] = mock_auth_hash("nobody@corp.example.com")

    post "/auth/entra_id"
    follow_redirect! # → new_session_path redirect

    get root_path
    assert_redirected_to new_session_path
  end

  # ---------------------------------------------------------------------------
  # Failure callback (invalid token / cancelled login)
  # ---------------------------------------------------------------------------

  test "OmniAuth failure redirects to sign-in with error message" do
    OmniAuth.config.mock_auth[:entra_id] = :invalid_credentials

    post "/auth/entra_id"
    follow_redirect!
    assert_redirected_to new_session_path
    follow_redirect!
    assert_match "Microsoft sign-in failed", response.body
  end

  test "direct GET to /auth/failure shows error message" do
    get "/auth/failure", params: { message: "access_denied" }

    assert_redirected_to new_session_path
    follow_redirect!
    assert_match "Microsoft sign-in failed", response.body
  end

  private

  def mock_auth_hash(email)
    OmniAuth::AuthHash.new(
      provider: "entra_id",
      uid: "oid-#{email}",
      info: OmniAuth::AuthHash::InfoHash.new(email: email),
      credentials: OmniAuth::AuthHash.new(token: "fake-token", expires_at: 1.hour.from_now.to_i)
    )
  end
end
