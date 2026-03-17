require "test_helper"

class PbixBaselineReporterTest < ActiveSupport::TestCase
  setup do
    [ MeetingPhoto, MeetingAttendance, Meeting, BookRequest, User, Member, ReservePolicy, FiscalPeriod ].each(&:delete_all)

    FiscalPeriod.create!(name: "FY2026", start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 12, 31), active: true)
    ReservePolicy.create!(member_role: "정회원", attendance_points: 5000, effective_from: Date.new(2026, 1, 1), effective_to: Date.new(2026, 12, 31))
    ReservePolicy.create!(member_role: "Lead", attendance_points: 10000, effective_from: Date.new(2026, 1, 1), effective_to: Date.new(2026, 12, 31))
    ReservePolicy.create!(member_role: "Lead:총무", attendance_points: 10000, effective_from: Date.new(2026, 1, 1), effective_to: Date.new(2026, 12, 31))

    Member.create!(english_name: "Hannah Lee", member_role: "정회원", active: true)
    Member.create!(english_name: "Gerald Park", member_role: "Lead:총무", active: true)
    BookRequest.create!(title: "Deep Work")
    Meeting.create!(title: "2026-02 Meetup", meeting_at: Time.zone.parse("2026-02-14 19:00:00"), reserve_exempt_default: false)
  end

  test "writes a markdown report with explicit matches and mismatches" do
    report_path = Rails.root.join("tmp/test_reconciliation_report.md")
    baseline_path = Rails.root.join("test/fixtures/reconciliation/current_state.json")

    report = Reconciliation::PbixBaselineReporter.new(
      baseline_path: baseline_path,
      report_path: report_path
    ).call

    assert_equal true, report[:development_ready]
    assert_equal false, report[:cutover_ready]
    assert_includes report[:blockers], "Book Requests"
    assert_includes report[:blockers], "Attendance Rows"

    content = report_path.read
    assert_includes content, "PBIX Baseline Reconciliation Report"
    assert_includes content, "Members | 2 | 2 | match"
    assert_includes content, "Book Requests | 10 | 1 | mismatch"
  end
end
