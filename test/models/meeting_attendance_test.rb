require "test_helper"

class MeetingAttendanceTest < ActiveSupport::TestCase
  test "enforces unique member per meeting" do
    member = Member.create!(english_name: "Hannah Lee", member_role: "정회원", active: true)
    meeting = Meeting.create!(title: "March Meetup", meeting_at: Time.zone.parse("2026-03-01 19:00:00"), reserve_exempt_default: false)

    MeetingAttendance.create!(meeting: meeting, member: member, reserve_exempt: false)
    duplicate = MeetingAttendance.new(meeting: meeting, member: member, reserve_exempt: false)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:member_id], "has already been taken"
  end
end
