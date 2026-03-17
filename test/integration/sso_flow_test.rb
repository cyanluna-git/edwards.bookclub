require "test_helper"

class AuthCallbacksControllerTest < ActionController::TestCase
  tests Auth::CallbacksController

  setup do
    [ MeetingPhoto, MeetingAttendance, Meeting, BookRequest, User, Member, ReservePolicy, FiscalPeriod ].each(&:delete_all)

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
  end

  test "successful entra callback creates rails session and redirects to root" do
    @request.env["omniauth.auth"] = mock_auth_hash(@user.email)

    get :entra_id

    assert_redirected_to root_path
    assert_equal "Signed in with Microsoft successfully.", flash[:notice]
    assert_equal @user.id, session[:user_id]
  end

  test "successful entra callback is case-insensitive on email" do
    @request.env["omniauth.auth"] = mock_auth_hash(@user.email.upcase)

    get :entra_id

    assert_redirected_to root_path
    assert_equal @user.id, session[:user_id]
  end

  test "admin can sign in via entra" do
    @request.env["omniauth.auth"] = mock_auth_hash(@admin.email)

    get :entra_id

    assert_redirected_to root_path
    assert_equal @admin.id, session[:user_id]
  end

  test "member email is auto-provisioned when no user exists yet" do
    linked_member = Member.create!(
      english_name: "Gerald Park",
      member_role: "정회원",
      active: true,
      email: "gerald.sso@example.com"
    )
    @request.env["omniauth.auth"] = mock_auth_hash(linked_member.email)

    assert_difference("User.count", 1) do
      get :entra_id
    end

    provisioned_user = User.find_by!(email: linked_member.email)
    assert_equal linked_member, provisioned_user.member
    assert_equal provisioned_user.id, session[:user_id]
    assert_redirected_to root_path
  end

  test "unknown email is rejected and redirected to sign-in" do
    @request.env["omniauth.auth"] = mock_auth_hash("nobody@corp.example.com")

    get :entra_id

    assert_redirected_to new_session_path
    assert_match "No Bookclub account is linked to nobody@corp.example.com", flash[:alert]
    assert_nil session[:user_id]
  end

  test "direct GET to /auth/failure shows error message" do
    get :failure, params: { message: "access_denied" }

    assert_redirected_to new_session_path
    assert_match "Microsoft sign-in failed", flash[:alert]
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

class SsoFlowTest < ActionDispatch::IntegrationTest
  test "sign-in page shows microsoft sign-in when entra vars are set" do
    with_env(
      "ENTRA_TENANT_ID" => "tenant-uuid",
      "ENTRA_CLIENT_ID" => "client-id",
      "ENTRA_CLIENT_SECRET" => "client-secret"
    ) do
      get new_session_path

      assert_response :success
      assert_match "Sign in with Microsoft", response.body
      assert_match "Use local fallback sign-in", response.body
    end
  end
end
