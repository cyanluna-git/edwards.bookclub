require "test_helper"

class HistoricalReserveReporterTest < ActiveSupport::TestCase
  setup do
    [MeetingPhoto, MeetingAttendance, Meeting, BookRequest, User, MemberOfficeAssignment, Member, ReservePolicy, FiscalPeriod].each(&:delete_all)

    @period = FiscalPeriod.create!(name: "FY2026", start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 12, 31), active: true)
    ReservePolicy.create!(member_role: "정회원", attendance_points: 5000, effective_from: @period.start_date, effective_to: @period.end_date)
    ReservePolicy.create!(member_role: "Lead", attendance_points: 10000, effective_from: @period.start_date, effective_to: @period.end_date)

    @member = Member.create!(english_name: "Gerald Park", member_role: "Lead", location: "아산", active: true)
    @other = Member.create!(english_name: "Hannah Lee", member_role: "정회원", location: "천안", active: true)
    @member.member_office_assignments.create!(office_type: "site_leader", location: "아산", effective_from: @period.start_date)

    meeting_one = Meeting.create!(title: "Morning meetup", meeting_at: Time.zone.parse("2026-03-14 09:00"), location: "아산", fiscal_period: @period)
    meeting_two = Meeting.create!(title: "Evening meetup", meeting_at: Time.zone.parse("2026-03-14 19:00"), location: "천안", fiscal_period: @period)
    pending_meeting = Meeting.create!(title: "Pending meetup", meeting_at: Time.zone.parse("2026-03-20 19:00"), location: "천안", fiscal_period: @period)

    MeetingAttendance.create!(meeting: meeting_one, member: @member, reserve_exempt: false, override_points: 7000, note: "acting secretary stipend")
    MeetingAttendance.create!(meeting: meeting_two, member: @member, reserve_exempt: false)
    attendance = MeetingAttendance.new(meeting: pending_meeting, member: @other, reserve_exempt: false)
    attendance.awarded_points = nil
    attendance.awarded_at = nil
    attendance.save!(validate: false)
  end

  test "writes explicit historical reserve exceptions and blockers" do
    report_path = Rails.root.join("tmp/test_historical_reserve_report.md")

    report = Reconciliation::HistoricalReserveReporter.new(report_path: report_path).call

    assert_equal false, report[:cutover_ready]
    assert_includes report[:blockers], "same-day multi-attendance exceptions"
    assert_includes report[:blockers], "attendance rows pending award snapshots"
    assert_equal 1, report[:manual_overrides].size

    content = report_path.read
    assert_includes content, "Historical Reserve Reconciliation Report"
    assert_includes content, "acting secretary stipend"
    assert_includes content, "Morning meetup"
    assert_includes content, "Pending meetup"
  end
end
