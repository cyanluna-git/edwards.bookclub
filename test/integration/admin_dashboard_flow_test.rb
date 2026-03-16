require "test_helper"

class AdminDashboardFlowTest < ActionDispatch::IntegrationTest
  setup do
    [MeetingPhoto, MeetingAttendance, Meeting, BookRequest, User, Member, ReservePolicy, FiscalPeriod].each(&:delete_all)

    @period = FiscalPeriod.create!(name: "FY2026", start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 12, 31), active: true)
    @member = Member.create!(english_name: "Hannah Lee", member_role: "정회원", active: true)
    @leader = Member.create!(english_name: "Gerald Park", member_role: "Lead", active: true)
    ReservePolicy.create!(member_role: "정회원", attendance_points: 5000, effective_from: @period.start_date, effective_to: @period.end_date)
    ReservePolicy.create!(member_role: "Lead", attendance_points: 10000, effective_from: @period.start_date, effective_to: @period.end_date)

    march_meeting = Meeting.create!(title: "March Meetup", meeting_at: Time.zone.parse("2026-03-12 19:00"), location: "천안", fiscal_period: @period, review: "Good energy")
    april_meeting = Meeting.create!(title: "April Meetup", meeting_at: Time.zone.parse("2026-04-09 19:00"), location: "아산", fiscal_period: @period)
    MeetingAttendance.create!(meeting: march_meeting, member: @member, reserve_exempt: false)
    MeetingAttendance.create!(meeting: march_meeting, member: @leader, reserve_exempt: false)
    MeetingAttendance.create!(meeting: april_meeting, member: @member, reserve_exempt: false)
    MeetingPhoto.create!(meeting: march_meeting, source_url: "https://example.com/march.jpg", caption: "March", sort_order: 1)

    BookRequest.create!(member: @member, fiscal_period: @period, title: "Thinking in Systems", price: 18000, additional_payment: 3000, requested_on: Date.new(2026, 3, 1))

    @admin = User.create!(email: "admin@example.com", password: "secret123", password_confirmation: "secret123", role: "admin")
    @member_user = User.create!(email: "member@example.com", password: "secret123", password_confirmation: "secret123", role: "member", member: @member)
  end

  test "admin can view dashboard metrics and breakdowns" do
    sign_in_as(@admin)

    get admin_dashboard_path

    assert_response :success
    assert_match "Operating dashboard", response.body
    assert_match "KRW 5,000", response.body
    assert_match "천안", response.body
    assert_match "March Meetup", response.body
  end

  test "dashboard can be filtered by month" do
    sign_in_as(@admin)

    get admin_dashboard_path, params: { month: "2026-04", fiscal_period_id: @period.id }

    assert_response :success
    assert_match "April Meetup", response.body
    assert_no_match "March Meetup", response.body
    assert_match "April 2026", response.body
  end

  test "member users cannot access dashboard" do
    sign_in_as(@member_user)

    get admin_dashboard_path

    assert_redirected_to root_path
  end

  private

  def sign_in_as(user)
    post session_path, params: { email: user.email, password: "secret123" }
    follow_redirect!
  end
end
