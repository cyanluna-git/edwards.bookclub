require "test_helper"

class MeetingAttendanceTest < ActiveSupport::TestCase
  setup do
    @period = FiscalPeriod.create!(name: "FY2026", start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 12, 31), active: true)
    ReservePolicy.create!(member_role: "정회원", attendance_points: 5000, effective_from: @period.start_date, effective_to: @period.end_date)
    ReservePolicy.create!(member_role: "Lead", attendance_points: 10000, effective_from: @period.start_date, effective_to: @period.end_date)
  end

  test "enforces unique member per meeting" do
    member = Member.create!(english_name: "Hannah Lee", member_role: "정회원", active: true)
    meeting = Meeting.create!(title: "March Meetup", meeting_at: Time.zone.parse("2026-03-01 19:00:00"), reserve_exempt_default: false, fiscal_period: @period)

    MeetingAttendance.create!(meeting: meeting, member: member, reserve_exempt: false)
    duplicate = MeetingAttendance.new(meeting: meeting, member: member, reserve_exempt: false)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:member_id], "has already been taken"
  end

  test "snapshots awarded points from office assignment and preserves override for effective points" do
    member = Member.create!(english_name: "Gerald Park", member_role: "정회원", location: "분당", active: true)
    member.member_office_assignments.create!(
      office_type: "site_leader",
      location: "분당",
      effective_from: Date.new(2026, 1, 1)
    )
    meeting = Meeting.create!(title: "Leader Meetup", meeting_at: Time.zone.parse("2026-03-01 19:00:00"), reserve_exempt_default: false, fiscal_period: @period)

    attendance = MeetingAttendance.create!(meeting:, member:, reserve_exempt: false, override_points: 12000)

    assert_equal 10000, attendance.awarded_points
    assert_equal "Lead", attendance.awarded_policy_role
    assert_equal 12000, attendance.effective_awarded_points
    assert_equal "Manual override", attendance.award_source_label
    assert_not_nil attendance.awarded_at
  end

  test "sets awarded points to zero when reserve exempt" do
    member = Member.create!(english_name: "Hannah Lee", member_role: "정회원", active: true)
    meeting = Meeting.create!(title: "Guest Meetup", meeting_at: Time.zone.parse("2026-03-10 19:00:00"), reserve_exempt_default: false, fiscal_period: @period)

    attendance = MeetingAttendance.create!(meeting:, member:, reserve_exempt: true)

    assert_equal 0, attendance.awarded_points
    assert_equal 0, attendance.effective_awarded_points
    assert_equal "Exempt", attendance.award_source_label
  end
end
