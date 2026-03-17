require "test_helper"

class ReportsFlowTest < ActionDispatch::IntegrationTest
  setup do
    [ MeetingPhoto, MeetingAttendance, Meeting, BookRequest, User, Member, ReservePolicy, FiscalPeriod ].each(&:delete_all)

    @period = FiscalPeriod.create!(name: "FY2026", start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 12, 31), active: true)
    @member = Member.create!(english_name: "Hannah Lee", member_role: "정회원", active: true)
    @other_member = Member.create!(english_name: "Gerald Park", member_role: "Lead", active: true)

    ReservePolicy.create!(member_role: "정회원", attendance_points: 5000, effective_from: @period.start_date, effective_to: @period.end_date)
    ReservePolicy.create!(member_role: "Lead", attendance_points: 10000, effective_from: @period.start_date, effective_to: @period.end_date)

    march_meeting = Meeting.create!(title: "March Meetup", meeting_at: Time.zone.parse("2026-03-12 19:00"), location: "천안", fiscal_period: @period, review: "Good energy")
    follow_up = Meeting.create!(title: "March Follow-up", meeting_at: Time.zone.parse("2026-03-24 19:00"), location: "동탄", fiscal_period: @period)
    MeetingAttendance.create!(meeting: march_meeting, member: @member, reserve_exempt: false)
    MeetingAttendance.create!(meeting: march_meeting, member: @other_member, reserve_exempt: false)
    MeetingAttendance.create!(meeting: follow_up, member: @member, reserve_exempt: false)
    MeetingPhoto.create!(meeting: march_meeting, source_url: "https://example.com/march.jpg", caption: "March", sort_order: 1)
    BookRequest.create!(member: @member, fiscal_period: @period, title: "Thinking in Systems", price: 18000, additional_payment: 3000, requested_on: Date.new(2026, 3, 1))

    @admin = User.create!(email: "admin@example.com", password: "secret123", password_confirmation: "secret123", role: "admin")
    @member_user = User.create!(email: "member@example.com", password: "secret123", password_confirmation: "secret123", role: "member", member: @member)
  end

  test "anonymous users cannot access reports" do
    get reports_path

    assert_redirected_to new_session_path
  end

  test "member users can access the shared reports page" do
    sign_in_as(@member_user)

    get reports_path

    assert_response :success
    assert_match "Reporting room", response.body
    assert_match "Meeting reviews", response.body
    assert_match "My Portal", response.body
    assert_no_match "Members", response.body
    assert_no_match "Open workspace", response.body
  end

  test "admin users can access the shared reports page with workspace shortcuts" do
    sign_in_as(@admin)

    get reports_path

    assert_response :success
    assert_match "Reporting room", response.body
    assert_match "Open workspace", response.body
    assert_match "Members", response.body
  end

  private

  def sign_in_as(user)
    post session_path, params: { email: user.email, password: "secret123" }
    follow_redirect!
  end
end
