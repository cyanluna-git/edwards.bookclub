require "test_helper"

class AdminSettingsFlowTest < ActionDispatch::IntegrationTest
  setup do
    [MeetingPhoto, MeetingAttendance, Meeting, BookRequest, User, Member, ReservePolicy, FiscalPeriod].each(&:delete_all)

    @period = FiscalPeriod.create!(name: "FY2026", start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 12, 31), active: true)
    @policy = ReservePolicy.create!(member_role: "정회원", attendance_points: 5000, effective_from: Date.new(2026, 1, 1), effective_to: Date.new(2026, 12, 31))
    @admin = User.create!(email: "admin@example.com", password: "secret123", password_confirmation: "secret123", role: "admin")
    @member_user = User.create!(email: "member@example.com", password: "secret123", password_confirmation: "secret123", role: "member")
  end

  test "admin can create and update fiscal periods" do
    sign_in_as(@admin)

    post admin_fiscal_periods_path, params: {
      fiscal_period: {
        name: "FY2027",
        start_date: "2027-01-01",
        end_date: "2027-12-31",
        active: "false"
      }
    }

    created = FiscalPeriod.find_by!(name: "FY2027")
    assert_redirected_to admin_fiscal_period_path(created)

    patch admin_fiscal_period_path(created), params: {
      fiscal_period: {
        active: "true"
      }
    }

    assert_response :unprocessable_content
    assert_match "allows only one active fiscal period at a time", response.body
  end

  test "admin can create and update reserve policies" do
    sign_in_as(@admin)

    post admin_reserve_policies_path, params: {
      reserve_policy: {
        member_role: "Lead",
        attendance_points: 10000,
        effective_from: "2026-01-01",
        effective_to: "2026-12-31"
      }
    }

    created = ReservePolicy.find_by!(member_role: "Lead")
    assert_redirected_to admin_reserve_policy_path(created)

    patch admin_reserve_policy_path(created), params: {
      reserve_policy: {
        attendance_points: 12000
      }
    }

    assert_redirected_to admin_reserve_policy_path(created)
    created.reload
    assert_equal 12000, created.attendance_points
  end

  test "settings screens block overlapping reserve policies" do
    sign_in_as(@admin)

    post admin_reserve_policies_path, params: {
      reserve_policy: {
        member_role: "정회원",
        attendance_points: 6000,
        effective_from: "2026-06-01",
        effective_to: "2027-05-31"
      }
    }

    assert_response :unprocessable_content
    assert_match "effective dates overlap an existing policy for this role", response.body
  end

  test "member users cannot access settings screens" do
    sign_in_as(@member_user)

    get admin_fiscal_periods_path

    assert_redirected_to root_path
  end

  private

  def sign_in_as(user)
    post session_path, params: { email: user.email, password: "secret123" }
    follow_redirect!
  end
end
