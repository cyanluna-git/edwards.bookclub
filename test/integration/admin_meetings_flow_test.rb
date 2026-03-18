require "test_helper"

class AdminMeetingsFlowTest < ActionDispatch::IntegrationTest
  setup do
    [ MeetingPhoto, MeetingAttendance, Meeting, MemberOfficeAssignment, BookRequest, User, Member, ReservePolicy, FiscalPeriod ].each(&:delete_all)

    @period = FiscalPeriod.create!(name: "FY2026", start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 12, 31), active: true)
    ReservePolicy.create!(member_role: "정회원", attendance_points: 5000, effective_from: @period.start_date, effective_to: @period.end_date)
    ReservePolicy.create!(member_role: "Lead", attendance_points: 10000, effective_from: @period.start_date, effective_to: @period.end_date)
    @member_one = Member.create!(english_name: "Hannah Lee", member_role: "정회원", location: "천안", active: true)
    @member_two = Member.create!(english_name: "Gerald Park", member_role: "Lead", location: "분당", active: true)
    @member_two.member_office_assignments.create!(office_type: "site_leader", location: "분당", effective_from: @period.start_date)
    @member_user = User.create!(email: "member@example.com", password: "secret123", password_confirmation: "secret123", role: "member", member: @member_one)
    @admin = User.create!(email: "admin@example.com", password: "secret123", password_confirmation: "secret123", role: "admin")
  end

  test "admin can create and edit meetings" do
    sign_in_as(@admin)

    post admin_meetings_path, params: {
      meeting: {
        title: "April Meetup",
        legacy_title: "2026-04 Meetup",
        meeting_at: "2026-04-12T19:00",
        location: "천안",
        description: "Monthly book discussion",
        review: "Strong turnout",
        reserve_exempt_default: "false",
        fiscal_period_id: @period.id
      }
    }

    meeting = Meeting.find_by!(title: "April Meetup")
    assert_redirected_to admin_meeting_path(meeting)

    patch admin_meeting_path(meeting), params: { meeting: { review: "Updated review", location: "아산" } }

    assert_redirected_to admin_meeting_path(meeting)
    meeting.reload
    assert_equal "Updated review", meeting.review
    assert_equal "아산", meeting.location
  end

  test "admin can manage attendees, reserve exemptions, and manual overrides" do
    sign_in_as(@admin)
    meeting = Meeting.create!(title: "Ops Meetup", meeting_at: Time.zone.parse("2026-05-10 19:00"), location: "천안", fiscal_period: @period, created_by: @admin)

    post admin_meeting_attendances_path(meeting), params: { meeting_attendance: { member_id: @member_one.id, reserve_exempt: "false", note: "On time" } }

    attendance = meeting.meeting_attendances.find_by!(member: @member_one)
    assert_redirected_to admin_meeting_path(meeting)
    assert_not attendance.reserve_exempt?
    assert_equal 5000, attendance.awarded_points

    post admin_meeting_attendances_path(meeting), params: { meeting_attendance: { member_id: @member_two.id, reserve_exempt: "false", override_points: "11000", note: "Leader" } }

    leader_attendance = meeting.meeting_attendances.find_by!(member: @member_two)
    assert_equal 10000, leader_attendance.awarded_points
    assert_equal 11000, leader_attendance.effective_awarded_points

    patch admin_meeting_attendance_path(meeting, attendance), params: { meeting_attendance: { reserve_exempt: "true", note: "Guest speaker", override_points: "" } }

    attendance.reload
    assert attendance.reserve_exempt?
    assert_equal "Guest speaker", attendance.note
    assert_equal 0, attendance.effective_awarded_points

    post admin_meeting_attendances_path(meeting), params: { meeting_attendance: { member_id: @member_one.id, reserve_exempt: "false" } }

    assert_redirected_to admin_meeting_path(meeting)
    follow_redirect!
    assert_match "Member has already been taken", response.body

    delete admin_meeting_attendance_path(meeting, attendance)

    assert_redirected_to admin_meeting_path(meeting)
    assert_nil meeting.meeting_attendances.find_by(id: attendance.id)
  end

  test "admin can manage photo records" do
    sign_in_as(@admin)
    meeting = Meeting.create!(title: "Photo Meetup", meeting_at: Time.zone.parse("2026-06-10 19:00"), location: "분당", created_by: @admin)

    post admin_meeting_photos_path(meeting), params: {
      meeting_photo: {
        source_url: "https://example.com/photo.jpg",
        caption: "Group photo",
        sort_order: "1"
      }
    }

    photo = meeting.meeting_photos.find_by!(caption: "Group photo")
    assert_redirected_to admin_meeting_path(meeting)

    patch admin_meeting_photo_path(meeting, photo), params: {
      meeting_photo: {
        file_path: "/uploads/photo.jpg",
        caption: "Updated group photo",
        sort_order: "2"
      }
    }

    photo.reload
    assert_equal "Updated group photo", photo.caption
    assert_equal 2, photo.sort_order

    delete admin_meeting_photo_path(meeting, photo)

    assert_redirected_to admin_meeting_path(meeting)
    assert_nil meeting.meeting_photos.find_by(id: photo.id)
  end

  test "member users cannot access meeting admin screens" do
    sign_in_as(@member_user)

    get admin_meetings_path

    assert_redirected_to root_path
  end

  test "meeting show page exposes the operations hub" do
    sign_in_as(@admin)
    meeting = Meeting.create!(title: "Hub Meetup", meeting_at: Time.zone.parse("2026-07-10 19:00"), location: "아산", review: "Great discussion", created_by: @admin)
    attendance = MeetingAttendance.create!(meeting:, member: @member_one, reserve_exempt: false, note: "Host")
    MeetingPhoto.create!(meeting:, source_url: "https://example.com/photo.jpg", caption: "Circle shot", sort_order: 1)

    get admin_meeting_path(meeting)

    assert_response :success
    assert_match "Attendance", response.body
    assert_match "Photos (1)", response.body
    assert_match attendance.note, response.body
    assert_match "Great discussion", response.body
    assert_match "Effective award", response.body
  end

  private

  def sign_in_as(user)
    post session_path, params: { email: user.email, password: "secret123" }
    follow_redirect!
  end
end
