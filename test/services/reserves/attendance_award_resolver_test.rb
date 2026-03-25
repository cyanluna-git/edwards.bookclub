require "test_helper"

module Reserves
  class AttendanceAwardResolverTest < ActiveSupport::TestCase
    setup do
      @period = FiscalPeriod.create!(name: "FY2026", start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 12, 31), active: true)
      ReservePolicy.create!(member_role: "정회원", attendance_points: 5000, effective_from: @period.start_date, effective_to: @period.end_date)
      ReservePolicy.create!(member_role: "Lead", attendance_points: 10000, effective_from: @period.start_date, effective_to: @period.end_date)
      @member = Member.create!(english_name: "Gerald Park", member_role: "정회원", location: "아산", active: true)
      @meeting = Meeting.create!(title: "April Meetup", meeting_at: Time.zone.parse("2026-04-12 19:00"), location: "아산", fiscal_period: @period)
    end

    test "uses standard member policy when no office assignment is active" do
      attendance = MeetingAttendance.new(meeting: @meeting, member: @member, reserve_exempt: false)

      result = AttendanceAwardResolver.new(attendance: attendance).call

      assert_equal "정회원", result.policy_role
      assert_equal 5000, result.awarded_points
      assert_equal 5000, result.effective_points
      assert_equal "member_policy", result.source
    end

    test "uses privileged office policy when an office assignment is active" do
      @member.member_office_assignments.create!(
        office_type: "site_leader",
        location: "아산",
        effective_from: Date.new(2026, 4, 1)
      )
      attendance = MeetingAttendance.new(meeting: @meeting, member: @member, reserve_exempt: false)

      result = AttendanceAwardResolver.new(attendance: attendance).call

      assert_equal "Lead", result.policy_role
      assert_equal 10000, result.awarded_points
      assert_equal "office_policy", result.source
      assert_includes result.office_labels, "지역 리더 · 아산"
    end

    test "keeps standard policy when only secretary office is active" do
      @member.update!(member_role: "정회원:총무")
      @member.member_office_assignments.create!(
        office_type: "secretary",
        effective_from: Date.new(2026, 4, 1)
      )
      attendance = MeetingAttendance.new(meeting: @meeting, member: @member, reserve_exempt: false)

      result = AttendanceAwardResolver.new(attendance: attendance).call

      assert_equal "정회원", result.policy_role
      assert_equal 5000, result.awarded_points
      assert_equal "member_policy", result.source
      assert_empty result.office_labels
    end

    test "prefers manual override for effective points" do
      attendance = MeetingAttendance.new(meeting: @meeting, member: @member, reserve_exempt: false, override_points: 7000)

      result = AttendanceAwardResolver.new(attendance: attendance).call

      assert_equal 5000, result.awarded_points
      assert_equal 7000, result.effective_points
      assert_equal "manual_override", result.source
    end
  end
end
